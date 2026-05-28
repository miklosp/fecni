# CLAUDE.md

macOS SwiftUI menu-bar app. Bundle identifier `work.miklos.fecni`, deployment target macOS 26.3, Swift 6.2 toolchain (MainActor-by-default isolation, approachable concurrency). Non-sandboxed, Developer ID.

**Goal: frictionless thought capture with native macOS UI.** A global shortcut opens a small floating editor centered above everything; you jot a note; on Esc / click-away it saves automatically as an Obsidian-flavored Markdown file into a user-configured vault folder. Editing is WYSIWYG (macOS 26 rich-text `TextEditor` + `AttributedString`), constrained to a small formatting set: bold, italic, H1/H2/H3, code block, and unordered / numbered / task lists. Pasting a URL over a selection wraps it as a Markdown link.

The current design lives in `docs/superpowers/specs/2026-05-28-fecni-design.md`. Read it before implementing.

## Architecture

- **App target (`fecni`)** — UI, `fecniApp` entry point, `AppCoordinator` (composition root), the capture-window `NSPanel` controller, settings UI, and the global-hotkey glue.
- **`Packages/CaptureKit/`** — local SPM umbrella holding the deterministic, testable core: `MarkdownDocument` (AttributedString ↔ Markdown round-trip), `VaultLocator` (Obsidian `obsidian.json` parsing / vault discovery), `CaptureStore` (filename + file writing), `Settings`.

### Dependencies
- [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) — global hotkey registration + rebind recorder UI (no Accessibility permission needed).
- [`swiftlang/swift-markdown`](https://github.com/swiftlang/swift-markdown) — Markdown normalization / serialization.

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

Two test surfaces:

- **SPM tests** (autonomous): deterministic logic in `CaptureKit` — `MarkdownDocument`, `VaultLocator`, `CaptureStore`, `Settings`. Run via `swift test --disable-sandbox --package-path Packages/CaptureKit`. The `--disable-sandbox` flag is required because SwiftPM's manifest compilation would otherwise call `sandbox_apply` and hit the nested-sandbox blocker.
- **App-hosted XCTest** (`fecniTests` target): integration smoke for code that needs a running `NSApp` (the capture panel, hotkey registration). Run via `./scripts/xcode-build-helper.sh -project fecni.xcodeproj -scheme fecni -destination 'platform=macOS' test`, or from Xcode (⌘U). The daemon runs `xcodebuild` outside the sandbox so the codesign path works.

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
