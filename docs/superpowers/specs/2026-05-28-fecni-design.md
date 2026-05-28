# fecni — design spec

**Date:** 2026-05-28
**Status:** approved (design); implementation pending

## Purpose

A macOS menu-bar app for **frictionless thought capture with native UI**. Press a global shortcut → a small editor window appears centered, above everything → jot a note → it saves automatically as an Obsidian-flavored Markdown file into a user-configured vault folder. Capture-and-forget.

## Constraints & decisions

- **Platform:** macOS 26.3 deployment target, Swift 6.2 toolchain, SwiftUI. MainActor-by-default isolation.
- **Distribution:** non-sandboxed, Developer ID (personal tool / outside the Mac App Store). This lets the app read `obsidian.json` and write into any folder without security-scoped bookmarks.
- **Bundle id:** `work.miklos.fecni`. Menu-bar–only agent app (`LSUIElement`, no Dock icon).

## App shape

- `MenuBarExtra` menu items: **New note** (shows the current hotkey), **Settings…**, **Open vault folder**, **Quit**.
- `AppCoordinator` is the composition root, wiring hotkey → capture window → store. Mirrors the audio-pipeline project's pattern.

## Capture window

- A custom `NSPanel` (not a `WindowGroup`):
  - Floating level above everything; `collectionBehavior` set so it appears on the active Space and over full-screen apps.
  - Centered on the screen with the mouse / key window. Can become key so it receives text input.
  - SwiftUI content hosted inside the panel.
- The global shortcut opens a **fresh, empty** panel each time.
- **Esc or click-away saves & closes.** An empty note writes no file.
- A debounced autosave writes a hidden draft to `~/Library/Application Support/work.miklos.fecni/draft.md` for crash recovery; the draft is cleared on a successful save.

## Editor

- macOS 26 rich-text `TextEditor` bound to an `AttributedString`, constrained by an `AttributedTextFormattingDefinition` to exactly the supported constructs (WYSIWYG: markup hidden, text shown styled).
- Block-level constructs use `PresentationIntent` (headings, lists, code blocks); inline uses inline intents (bold/italic/code span/link).
- Formatting set and key bindings:

  | Format | Key |
  |---|---|
  | Bold | ⌘B |
  | Italic | ⌘I |
  | Heading 1 / 2 / 3 | ⌘1 / ⌘2 / ⌘3 |
  | Code block | ⌘E |
  | Task list | ⌘L |
  | Unordered list | ⇧⌘U |
  | Numbered list | ⇧⌘O |

- **Paste-link behavior:** pasting a URL with a non-empty selection wraps it as `[selected text](url)`; with no selection, the bare URL is inserted.
- **Design:** super simple — just the text field with generous padding. A `keyboard` SF Symbol button sits bottom-right; clicking it toggles a footer listing the shortcuts above.

## Markdown persistence

- **File model:** one new file per capture, written on dismiss. Filename `yyyy-MM-dd HHmm.md` (collision-safe suffix if needed), written into the configured vault + subfolder.
- A `MarkdownDocument` boundary converts both ways:
  - **Load:** Foundation `AttributedString(markdown:)`.
  - **Save:** a custom AttributedString → Markdown serializer that walks inline runs + `PresentationIntent` blocks, normalized through **swift-markdown** for correct escaping/formatting.
- This boundary isolates the one genuinely risky area (block-level round-trip) behind a single, unit-testable interface.

## Vault detection & settings

- Settings window (opened from the menu):
  - Reads `~/Library/Application Support/obsidian/obsidian.json` to list detected vaults → user picks one → picks a subfolder (default: vault root; offers existing folders such as `00-Inbox`).
  - A `KeyboardShortcuts.Recorder` rebinds the global hotkey. Default: **⌃⌥Space**.
- Settings persisted via `UserDefaults` / `@AppStorage`. Vault stored as a path string (no bookmark needed — non-sandboxed).

## Dependencies

- **`sindresorhus/KeyboardShortcuts`** — global hotkey registration + rebind recorder UI. No Accessibility permission required.
- **`swiftlang/swift-markdown`** — Markdown normalization / serialization.
- **`gonzalezreal/textual` — dropped.** It is a read-only renderer; nothing here displays Markdown read-only (the footer is static key labels). Reconsider only if a live preview pane is wanted later.

## Code structure

- **App target (`fecni`):** UI, `fecniApp`, `AppCoordinator`, the `NSPanel` controller, settings UI, hotkey glue.
- **`Packages/CaptureKit/`** (local SPM umbrella, the testable core):
  - `MarkdownDocument` — AttributedString ↔ Markdown round-trip.
  - `VaultLocator` — `obsidian.json` parsing / vault discovery.
  - `CaptureStore` — filename generation + file writing.
  - `Settings` — typed settings model.

## Testing

- **SPM tests** (`swift test --disable-sandbox --package-path Packages/CaptureKit`):
  - Markdown round-trip across every supported construct.
  - `obsidian.json` parsing against a fixture.
  - Filename generation (incl. collision handling).
  - Settings encode/decode + defaults.
- **App-hosted XCTest** (`fecniTests`): panel show/hide, hotkey registration, `NSApp` integration.
- Scaffolding via `scripts/run-setup-spm-package.sh CaptureKit` and `scripts/run-setup-tests.sh`.

## Out of scope (v1)

- Live preview / split pane, Obsidian-style per-line markup reveal.
- Editing existing notes (capture-only).
- Tables, blockquotes, images, footnotes, frontmatter.
- iCloud sync (the vault handles its own sync).

## Open implementation notes

- Raise `SWIFT_VERSION` from the template's `5.0` to `6.0` language mode during setup.
- Verify how faithfully the macOS 26 rich-text `TextEditor` + `AttributedTextFormattingDefinition` handles block constructs (headings/lists/code) in practice; the `MarkdownDocument` interface is the seam if a fallback is needed.

### Carried over from CaptureKit implementation + review (for Plan 2)

- **Editor-produced AttributedStrings (Plan 2 must verify):** `MarkdownDocument.markdown(from:)` separates blocks using `presentationIntent` identity and the load-path's synthetic `intent == nil` newline-separator runs. An `AttributedString` coming from the live `TextEditor` will NOT carry those synthetic separators, and two adjacent same-styled paragraphs may share/merge intents. When wiring the editor, confirm how `TextEditor` structures `presentationIntent` across paragraphs and add an editor→Markdown test; adjust the block-grouping if needed.
- **Soft/hard breaks are normalized to a single space on load** (`SoftBreak`/`LineBreak` → `" "`). Captured notes are saved block-per-line so this only affects externally-authored Markdown opened later; acceptable for v1.
- **Nested lists and code-blocks-inside-list-items lose depth on save** (single-level lists only — matches v1 scope). Revisit if nesting is ever wanted.
- **Cosmetic (deferred):** nested inline emphasis (e.g. bold inside italic) emits redundant but idempotent markers like `*a **b** c*` with extra `*`/`**` per run. Round-trips correctly; only the on-disk text is slightly noisy. Fix by coalescing adjacent runs sharing an inline intent if it ever matters.
- `TaskItem.swift` defines `AttributeScopes.FecniAttributes` + an `AttributeDynamicLookup` subscript that CaptureKit itself doesn't use (it accesses `[TaskItemAttribute.self]` directly) — intended for Plan 2's `AttributedTextFormattingDefinition`/SwiftUI usage.
