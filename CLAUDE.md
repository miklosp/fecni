# CLAUDE.md

macOS SwiftUI menu-bar app. Bundle identifier `work.miklos.fecni`, deployment target macOS 26.3, Swift 6.2 toolchain (MainActor-by-default isolation, approachable concurrency). Non-sandboxed, Developer ID.

**Goal: frictionless thought capture with native macOS UI.** A global shortcut opens a small floating editor centered above everything; you jot a note; on Esc / click-away it saves automatically as an Obsidian-flavored Markdown file into a user-configured vault folder. The editor is **MarkdownEngine** (native TextKit 2, bridged to SwiftUI): you edit Markdown text directly and it renders styled live (headings, bullet/numbered/task lists, code, links — "markup visible but styled"). Because the editor's document *is* Markdown, the in-progress note is a plain `String` and saving just writes it — no AttributedString↔Markdown conversion.

The original design lives in `docs/superpowers/specs/2026-05-28-fecni-design.md`. NOTE: the editor approach changed after the spec was written — SwiftUI's `TextEditor` + `AttributedString` could not render block-level constructs (headings/lists/code) live, so we adopted MarkdownEngine instead (a native TextKit 2 editor). The spec's editor section is therefore historical; the storage/vault/settings design still holds.

## Architecture

- **App target (`fecni`)** — UI, `fecniApp` entry point, `AppCoordinator` (composition root), the capture-window `NSPanel` controller, the `CaptureView` hosting MarkdownEngine's `NativeTextViewWrapper`, settings UI, and the global-hotkey glue.
- **`Packages/CaptureKit/`** — local SPM umbrella holding the deterministic, testable core: `VaultLocator` (Obsidian `obsidian.json` parsing / vault discovery), `CaptureStore` (filename + file writing), `CaptureSettings`/`SettingsStore`. No Markdown serialization (the editor works in Markdown text directly); CaptureKit has no external dependencies.

### Dependencies
- [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) — global hotkey registration + rebind recorder UI (no Accessibility permission needed).
- [`nodes-app/swift-markdown-engine`](https://github.com/nodes-app/swift-markdown-engine) (`MarkdownEngine`, pinned 0.5.0, Apache-2.0) — native TextKit 2 Markdown editor, the capture text surface. Optional add-on products (`MarkdownEngineCodeBlocks`, `MarkdownEngineLatex`) are not currently linked.

## Build & run

There is no Xcode workspace, only the `.xcodeproj`. Outside the Claude Code sandbox (regular terminal, Xcode):

```bash
xcodebuild -project fecni.xcodeproj -scheme fecni -configuration Debug build
xcodebuild -project fecni.xcodeproj -scheme fecni clean
xcodebuild -project fecni.xcodeproj -scheme fecni -configuration Debug -showBuildSettings | rg '^\s+BUILT_PRODUCTS_DIR'
```
To launch the built app: `open <BUILT_PRODUCTS_DIR>/fecni.app`. For interactive development, opening the `.xcodeproj` in Xcode and using ⌘R is faster.

Inside the Claude Code sandbox, `xcodebuild` self-refuses ("Cannot run while sandboxed") — route builds/tests through the `xcode-build` skill / `scripts/xcode-build-helper.sh`, which dispatch to the outside-sandbox Hammerspoon daemon.

## Tests

**SPM tests** (autonomous): deterministic logic in `CaptureKit` — `VaultLocator`, `CaptureStore`, `CaptureSettings`/`SettingsStore`. Run via `swift test --disable-sandbox --package-path Packages/CaptureKit`. The `--disable-sandbox` flag is required because SwiftPM's manifest compilation would otherwise call `sandbox_apply` and hit the nested-sandbox blocker.

> **App-hosted XCTest is currently broken on this toolchain (Xcode 26.x):** instantiating any `fecni` app-module type from the app-hosted test bundle double-frees (`malloc: pointer being freed was not allocated`). The app itself is unaffected. So keep testable logic in `CaptureKit` (verified via `swift test`); app behavior is verified by running the app. The `fecniTests` target is therefore not created — recreate it via `scripts/run-setup-tests.sh` to retry on a future toolchain.

### Scaffolding scripts

- `scripts/run-setup-spm-package.sh <ProductName>` — registers `Packages/CaptureKit` as a local package and links the named product into the `fecni` app target.
- `scripts/run-setup-tests.sh` — creates/syncs the `fecniTests` target and writes a shared `fecni` scheme.

Both install the `xcodeproj` gem into `/tmp/fecni-gems` on first run.

## `apple-docs` CLI

Local snapshot of Apple developer documentation: DocC reference, Human Interface Guidelines, Swift Evolution, App Store Review Guidelines, plus more. Data lives at `~/.apple-docs/`. Prefer this over `find-docs` (Context7) for Apple-platform queries — the corpus covers HIG and Swift Evolution, which Context7 does not.

```bash
apple-docs search "TextEditor AttributedString"        # search by term or symbol
apple-docs read swiftui/texteditor                     # full page
apple-docs browse swiftui                               # framework topic tree
apple-docs --help                                       # full command list
```
Add `--json` for scripted/parseable output.
