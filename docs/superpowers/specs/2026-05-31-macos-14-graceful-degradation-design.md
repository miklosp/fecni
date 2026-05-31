# macOS 14+ graceful degradation — design spec

**Date:** 2026-05-31
**Status:** approved (design); implementation pending
**Supersedes the platform floor in:** `2026-05-28-fecni-design.md` (macOS 26.3) and builds on `2026-05-30-shortcuts-hint-liquid-glass-design.md` (the glass pill it degrades).

## Purpose

Lower fecni's deployment target from macOS 26.3 to **macOS 14.0** so the app runs on macOS 14 and later, while preserving the Liquid Glass experience on macOS 26+ and degrading gracefully below it. The only user-visible degradation is how the keyboard-shortcut hints are presented.

## Why this is small

An audit of the whole app found exactly one cluster of version-gated SwiftUI, all in `ShortcutsHint.swift`:

- `GlassEffectContainer` + `.glassEffect(.regular.interactive(), in:)` — **macOS 26 only**
- `.onGeometryChange(for:action:)` — macOS 15+ (only measures the expanding pill)
- `.contentTransition(.symbolEffect(.replace))` — macOS 14+ (within the new floor; no guard needed)

Everything else clears macOS 14:

- **MarkdownEngine** (the editor core) already declares `.macOS(.v14)`; the fork pin does not raise the floor.
- **KeyboardShortcuts** supports macOS 10.15+.
- **CaptureKit** is pure Foundation logic — no SwiftUI/AppKit, no version-gated APIs.
- The `NSPanel` / transparent-titlebar / hotkey code uses long-stable AppKit.
- Swift 6.2 MainActor-by-default isolation and approachable concurrency are *compile-time* features; the concurrency runtime back-deploys well below 14.

## Constraints & decisions

- **New floor:** macOS 14.0. No intermediate tier for 15–25 — everything below 26 gets the same fallback.
- **macOS 26+:** the existing collapsed-circle-that-expands glass pill is **unchanged**.
- **macOS 14–25:** a **reserved footer strip** below the editor showing all hints, always on. Chosen over a floating overlay so note text can never scroll behind and clash with the hints (there is no glass/material to separate them).
- No new material or scrim is added to the macOS 26 pill. No glass anywhere below 26.
- Storage / vault / settings / hotkey logic is untouched.

## Design

### 1. Deployment target

- `fecni.xcodeproj` — `MACOSX_DEPLOYMENT_TARGET` **26.3 → 14.0** in both build configurations (`project.pbxproj` lines ~198 and ~255).
- `Packages/CaptureKit/Package.swift` — `platforms: [.macOS("26.0")]` → `[.macOS(.v14)]`.

### 2. Compiler as the completeness check

Lowering the target makes the Swift compiler error on **every** unguarded API newer than 14.0. The audit above found only the glass cluster, but rather than rely on a manual sweep the procedure is:

> lower the target → build → fix each availability error the compiler reports → repeat until the build is clean.

This turns the compiler into an exhaustive verifier; any API I missed surfaces as a hard error rather than a runtime crash on an older OS.

### 3. `ShortcutsHint.swift` — two views, one data source

- Factor the hint data into a single shared constant, `shortcutHintItems: [(keys: String, label: String)]`, so both presentations stay in sync. (Today's literal: `("⌘1/2/3", "Heading")`, `("⌘B", "Bold")`, `("⌘I", "Italic")`.)
- **`ShortcutsHint`** (the glass pill) — internals unchanged (`GlassEffectContainer`, `.glassEffect`, `.onGeometryChange`, the symbol-replace toggle). It reads `shortcutHintItems`. The struct is annotated `@available(macOS 26, *)` so its body's macOS-26/15 APIs compile at the 14 floor — instantiation-site guarding alone is *not* enough, since availability does not propagate into `body`. It is therefore only ever referenced from an `if #available(macOS 26, *)` context.
- **`ShortcutsFooter`** (new) — a static, horizontally-centered `HStack` of the same chips: keys in `.caption.monospaced()`, labels in `.caption` with `.secondary` foreground, matching the approved screenshot. No glass, no expand/collapse, no `onGeometryChange`. Lives in the same file as `ShortcutsHint`.

### 4. `CaptureView` — branch the layout

The two presentations place the hints differently (floating overlay vs. reserved strip), so the availability branch lives in `CaptureView`, not inside a single hint view:

```swift
private var editor: some View {
    NativeTextViewWrapper(text: $model.text, configuration: editorConfiguration)
        .onChange(of: model.text) { _, _ in model.textChanged() }
}

var body: some View {
    Group {
        if #available(macOS 26, *) {
            editor.overlay(alignment: .bottomTrailing) {
                ShortcutsHint().padding(12)
            }
        } else {
            VStack(spacing: 0) {
                editor
                Divider()
                ShortcutsFooter()
            }
        }
    }
    .frame(minWidth: 460, minHeight: 280)
    .ignoresSafeArea(.container, edges: .top)
    .onExitCommand { model.requestDismiss() }
}
```

On 14–25 the strip occupies part of the existing 280pt minimum height (the editor shrinks by the strip's height); `minHeight` stays 280. The top `.ignoresSafeArea(.container, edges: .top)` still applies to the editor, which remains the top element in both branches.

## Verification

- **CaptureKit:** `swift test --disable-sandbox --package-path Packages/CaptureKit` stays green after the platform bump.
- **Build:** compiles cleanly with the 14.0 target via the `xcode-build` skill (this is also step 2's completeness check — the build must be free of availability errors).
- **macOS 26 path:** glass pill visually unchanged on this machine.
- **Fallback path:** the dev machine runs macOS 26, so the `else` branch never executes here at runtime. Verify the strip's appearance by **temporarily** forcing the branch (e.g. change the guard to `if false`), screenshot, then revert. This is the one path that cannot be runtime-verified on current hardware; flagged so it gets an explicit manual check.

## Out of scope

- No intermediate material-pill tier for macOS 15–25 (the always-on strip covers everything below 26).
- No material/scrim added to the macOS 26 glass pill.
- No changes to storage, vault discovery, settings, draft handling, or the global hotkey.
