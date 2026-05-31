# macOS 14+ Graceful Degradation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lower fecni's deployment target from macOS 26.3 to macOS 14.0, preserving the Liquid Glass shortcut pill on macOS 26+ and falling back to an always-on shortcuts footer on macOS 14–25.

**Architecture:** The only version-gated SwiftUI in the app is the glass pill in `ShortcutsHint.swift`. We annotate that view `@available(macOS 26, *)`, add a plain `ShortcutsFooter` for older systems, and branch the layout in `CaptureView` (glass overlay on 26+, reserved footer strip below 26). Lowering the deployment target turns the Swift compiler into an exhaustive checker for any other unguarded newer-than-14 API.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (`NSPanel`), SPM (CaptureKit local package), MarkdownEngine. Builds route through the `xcode-build` skill (xcodebuild self-refuses in-sandbox); CaptureKit tests run in-session via `swift test --disable-sandbox`.

**Spec:** `docs/superpowers/specs/2026-05-31-macos-14-graceful-degradation-design.md`

**Build/commit invariant:** Every task leaves the project building. The deployment-target drop (Task 3) lands together with the `CaptureView` availability guard that makes it compile cleanly — they are one logical unit and must not be split.

---

### Task 1: Lower CaptureKit platform floor to macOS 14

CaptureKit is pure Foundation logic (no SwiftUI/AppKit, no version-gated APIs), so the only change is the manifest platform; its existing tests are the regression check.

**Files:**
- Modify: `Packages/CaptureKit/Package.swift:6`

- [ ] **Step 1: Lower the platform**

Replace:

```swift
    platforms: [.macOS("26.0")],
```

with:

```swift
    platforms: [.macOS(.v14)],
```

- [ ] **Step 2: Run CaptureKit tests to verify they still pass**

Run (in-session, not via xcode-build):

```bash
swift test --disable-sandbox --package-path Packages/CaptureKit
```

Expected: compiles against the macOS 14 platform and every test passes (`VaultLocatorTests`, `CaptureStoreTests`, `CaptureSettingsTests`, `SmokeTests`) — `0 failures`.

- [ ] **Step 3: Commit**

```bash
git add Packages/CaptureKit/Package.swift
git commit -m "chore: lower CaptureKit platform floor to macOS 14"
```

---

### Task 2: Gate `ShortcutsHint` behind macOS 26 and add `ShortcutsFooter`

Extract the hint data into one shared constant, annotate the glass pill `@available(macOS 26, *)` (so its `body`'s glass/`onGeometryChange` calls compile once the target drops), and add the plain footer used on older systems. The deployment target is still 26.3 here, so the `@available` annotation is a no-op and `ShortcutsFooter` is simply unused — the build stays green.

**Files:**
- Modify: `fecni/ShortcutsHint.swift`

- [ ] **Step 1: Add the shared hint-data constant above `ShortcutsHint`**

Replace the file's top (lines 1–17, from `import SwiftUI` through the closing `]` of the `items` array) — i.e. replace this:

```swift
import SwiftUI

/// A Liquid Glass pill in the editor's bottom-right corner. Collapsed, it's a
/// small glass circle showing the `keyboard` glyph. Expanding grows the glass
/// capsule leftward, unmasking the keyboard-shortcut hints right-to-left — the
/// hints stay put; the widening glass simply reveals more of them.
///
/// The toggle glyph is a *separate overlay* pinned to the trailing edge, not
/// part of the clipped, growing track, so it can never move with the reveal —
/// it only morphs `keyboard` ⟷ ✕ in place via the native symbol-replace
/// transition.
struct ShortcutsHint: View {
    private let items: [(keys: String, label: String)] = [
        ("⌘1/2/3", "Heading"),
        ("⌘B", "Bold"),
        ("⌘I", "Italic"),
    ]

```

with this:

```swift
import SwiftUI

/// The keyboard-shortcut hints shown in the editor, shared by the macOS 26+
/// glass pill (`ShortcutsHint`) and the macOS 14–25 footer (`ShortcutsFooter`).
let shortcutHintItems: [(keys: String, label: String)] = [
    ("⌘1/2/3", "Heading"),
    ("⌘B", "Bold"),
    ("⌘I", "Italic"),
]

/// A Liquid Glass pill in the editor's bottom-right corner. Collapsed, it's a
/// small glass circle showing the `keyboard` glyph. Expanding grows the glass
/// capsule leftward, unmasking the keyboard-shortcut hints right-to-left — the
/// hints stay put; the widening glass simply reveals more of them.
///
/// The toggle glyph is a *separate overlay* pinned to the trailing edge, not
/// part of the clipped, growing track, so it can never move with the reveal —
/// it only morphs `keyboard` ⟷ ✕ in place via the native symbol-replace
/// transition.
@available(macOS 26, *)
struct ShortcutsHint: View {
```

(This both adds the shared constant and removes the now-redundant `private let items` property, replacing it with the `@available` annotation.)

- [ ] **Step 2: Point the pill's `ForEach` at the shared constant**

In `ShortcutsHint`'s `glassTrack`, replace:

```swift
            ForEach(items, id: \.keys) { item in
```

with:

```swift
            ForEach(shortcutHintItems, id: \.keys) { item in
```

- [ ] **Step 3: Add `ShortcutsFooter` at the end of the file**

Append after the closing brace of `ShortcutsHint`:

```swift

/// The always-on shortcut hints shown below the editor on macOS 14–25, where
/// Liquid Glass (and the expanding `ShortcutsHint` pill) is unavailable. A
/// static, horizontally-centered row of the same chips — no glass, no
/// expand/collapse, no geometry measurement.
struct ShortcutsFooter: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(shortcutHintItems, id: \.keys) { item in
                HStack(spacing: 6) {
                    Text(item.keys).font(.caption.monospaced())
                    Text(item.label).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 4: Build to verify it still compiles (target still 26.3)**

Build via the `xcode-build` skill:

```bash
xcodebuild -project fecni.xcodeproj -scheme fecni -configuration Debug build
```

Expected: `BUILD SUCCEEDED`. `ShortcutsFooter` is defined but unreferenced — Swift does not warn on unreferenced types, so the build is clean.

- [ ] **Step 5: Commit**

```bash
git add fecni/ShortcutsHint.swift
git commit -m "refactor: gate ShortcutsHint behind macOS 26 and add ShortcutsFooter"
```

---

### Task 3: Branch `CaptureView` layout and drop the deployment target to 14.0

This is the one logical unit: the `CaptureView` availability guard and the deployment-target drop land in the same commit, because the guard is what makes the lowered target compile (and what makes the now-meaningful `#available` check warning-free).

**Files:**
- Modify: `fecni/CaptureView.swift:55-69`
- Modify: `fecni.xcodeproj/project.pbxproj:198,255`

- [ ] **Step 1: Extract the editor and branch the body**

In `CaptureView`, replace the current `body` (lines 55–69):

```swift
    var body: some View {
        NativeTextViewWrapper(text: $model.text, configuration: editorConfiguration)
            .onChange(of: model.text) { _, _ in model.textChanged() }
            .overlay(alignment: .bottomTrailing) {
                ShortcutsHint()
                    .padding(12)
            }
            .frame(minWidth: 460, minHeight: 280)
            // The panel's full-size-content titlebar is transparent and empty;
            // without this SwiftUI insets content below the (invisible) titlebar,
            // making the top gap larger than the sides. Extend into it so the
            // editor's own 20pt text inset is the only top padding.
            .ignoresSafeArea(.container, edges: .top)
            .onExitCommand { model.requestDismiss() }
    }
```

with:

```swift
    private var editor: some View {
        NativeTextViewWrapper(text: $model.text, configuration: editorConfiguration)
            .onChange(of: model.text) { _, _ in model.textChanged() }
    }

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                // macOS 26+: the Liquid Glass pill floats in the corner.
                editor.overlay(alignment: .bottomTrailing) {
                    ShortcutsHint()
                        .padding(12)
                }
            } else {
                // macOS 14–25: a reserved footer strip below the editor so note
                // text can never scroll behind the hints.
                VStack(spacing: 0) {
                    editor
                    Divider()
                    ShortcutsFooter()
                }
            }
        }
        .frame(minWidth: 460, minHeight: 280)
        // The panel's full-size-content titlebar is transparent and empty;
        // without this SwiftUI insets content below the (invisible) titlebar,
        // making the top gap larger than the sides. Extend into it so the
        // editor's own 20pt text inset is the only top padding.
        .ignoresSafeArea(.container, edges: .top)
        .onExitCommand { model.requestDismiss() }
    }
```

- [ ] **Step 2: Lower the app deployment target**

In `fecni.xcodeproj/project.pbxproj`, replace **both** occurrences (lines 198 and 255 — the project-level Debug and Release configs; target-level configs inherit):

```
				MACOSX_DEPLOYMENT_TARGET = 26.3;
```

with:

```
				MACOSX_DEPLOYMENT_TARGET = 14.0;
```

(Both lines are byte-identical, so a replace-all is safe; verify afterward with `rg -c "MACOSX_DEPLOYMENT_TARGET = 14.0" fecni.xcodeproj/project.pbxproj` → `2`, and `rg -c "26.3" fecni.xcodeproj/project.pbxproj` → no matches.)

- [ ] **Step 3: Build at target 14.0 — the completeness check**

Build via the `xcode-build` skill:

```bash
xcodebuild -project fecni.xcodeproj -scheme fecni -configuration Debug build
```

Expected: `BUILD SUCCEEDED` with no availability errors.

Contingency: the compiler now flags **every** unguarded API newer than macOS 14. The audit found only the glass cluster (already handled). If any other `'<API>' is only available in macOS <N> or newer` error appears, fix it before committing — wrap the call site in `if #available(macOS N, *)` with a 14-compatible fallback, or annotate the enclosing type `@available(macOS N, *)` if it is itself only reachable from a guarded context. Re-run the build until clean.

- [ ] **Step 4: Commit**

```bash
git add fecni/CaptureView.swift fecni.xcodeproj/project.pbxproj
git commit -m "feat: support macOS 14+ via always-on shortcuts footer fallback"
```

---

### Task 4: Verify both presentations (no commit)

This machine runs macOS 26, so the glass path verifies at runtime directly; the fallback path cannot execute here and must be checked by temporarily forcing it.

**Files:**
- Temporarily modify then revert: `fecni/CaptureView.swift`

- [ ] **Step 1: Verify the macOS 26 glass path (runtime)**

Build and launch the app (see `CLAUDE.md` Build & run, or the `run` skill). Trigger the capture window. Confirm: the glass pill sits in the bottom-right; tapping the keyboard glyph expands the capsule leftward to reveal `⌘1/2/3 Heading  ⌘B Bold  ⌘I Italic`; the toggle glyph morphs `keyboard ⟷ ✕`. This is unchanged behavior.

- [ ] **Step 2: Force the fallback branch to verify the footer**

Temporarily replace the whole `if #available(macOS 26, *) { … } else { … }` block in `CaptureView.body`'s `Group` with **only** the fallback contents (so it compiles at target 14 — `ShortcutsHint` must not be referenced outside an availability guard):

```swift
        Group {
            VStack(spacing: 0) {
                editor
                Divider()
                ShortcutsFooter()
            }
        }
```

Build via `xcode-build`, launch, trigger the capture window. Confirm: a divider sits below the editor with a centered row `⌘1/2/3 Heading  ⌘B Bold  ⌘I Italic` (monospace keys, secondary-colored labels); typing a long note stops above the divider and never overlaps the hints.

- [ ] **Step 3: Revert the temporary change**

```bash
git checkout fecni/CaptureView.swift
```

Confirm the file matches the committed Task 3 version (`git status` clean for `fecni/CaptureView.swift`).

---

## Verification summary

- CaptureKit: `swift test --disable-sandbox --package-path Packages/CaptureKit` — all pass (Task 1).
- App build at target 14.0: `BUILD SUCCEEDED`, no availability errors (Task 3 — also the exhaustive completeness check).
- macOS 26 glass pill: visually unchanged (Task 4 Step 1).
- macOS 14–25 footer strip: verified via forced branch, then reverted (Task 4 Steps 2–3).
