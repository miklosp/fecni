# CLAUDE.md

macOS SwiftUI **menu-bar app** for frictionless note capture. Swift 6.2 toolchain
(MainActor-by-default isolation, approachable concurrency), deployment target macOS 14.0,
bundle id `work.miklos.fecni`, non-sandboxed Developer ID. Liquid Glass UI is gated to
macOS 26+ with a graceful fallback. Human-facing overview: `README.md`.

> **Editor:** the capture surface is **MarkdownEngine** (native TextKit 2), not SwiftUI
> `TextEditor`. The in-progress note is a plain Markdown `String`, so saving just writes it
> — no AttributedString↔Markdown conversion. The original spec
> (`docs/superpowers/specs/2026-05-28-fecni-design.md`) predates this switch (TextEditor
> couldn't render block constructs live); its editor section is historical, but the
> storage/vault/settings design still holds.

## Architecture

- **App target (`fecni/`)** — SwiftUI UI + AppKit glue: `fecniApp` (entry), `AppCoordinator`
  (composition root), `CapturePanel`/`CapturePanelController` (floating `NSPanel`),
  `CaptureView` (hosts MarkdownEngine), `SettingsView`, `DraftStore` (crash-recovery
  autosave), `Hotkey` (global shortcut).
- **`Packages/CaptureKit/`** — local SPM package, the deterministic/testable core with no
  external deps: `VaultLocator` (Obsidian `obsidian.json` parsing), `CaptureStore` (filename
  + file writing), `CaptureSettings`/`SettingsStore`.

## Build, run, test

- **App:** open `fecni.xcodeproj` in Xcode and ⌘R, or `xcodebuild` (commands in `README.md`).
- **CaptureKit tests** (the deterministic core): `swift test --package-path Packages/CaptureKit`.

> **App-hosted XCTest is broken on this toolchain (Xcode 26.x):** instantiating any `fecni`
> app-module type from the test bundle double-frees. So there is **no `fecniTests` target** —
> keep testable logic in `CaptureKit` (verified via `swift test`); verify app behavior by
> running the app. Recreate the target via `scripts/run-setup-tests.sh` to retry on a future
> toolchain.

### Scaffolding scripts
- `scripts/run-setup-spm-package.sh <ProductName>` — link a CaptureKit product into the app target.
- `scripts/run-setup-tests.sh` — (re)create the `fecniTests` target + shared scheme.

Both install the `xcodeproj` gem into `/tmp/fecni-gems` on first run.
