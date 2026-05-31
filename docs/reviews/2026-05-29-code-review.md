# Code Review Findings — 2026-05-29

**Scope:** all authored Swift on `main` (app target `fecni/` + `Packages/CaptureKit/`) as of commit `8519c33`. This is a from-scratch project, so the review covers the current state of the code, not a small diff.

**Method:** `/code-review max` — 9 finder angles across 5 parallel reviewers, verified line-by-line against the source, plus a gap sweep. Refuted candidates are listed at the end so they aren't re-investigated.

**Status legend:** CONFIRMED = trigger + wrong outcome named against the code. PLAUSIBLE = real mechanism, trigger depends on timing/runtime (needs a run to confirm).

---

## Resolution — 2026-05-31

All findings dispositioned; closed out. Fixes landed in the follow-up session (commit `a932b2d`) unless noted.

- **F1, F2, F3** — fixed. `commit()`/`recoverDraftIfPresent()` route through `persist()`, which clears the draft only after a confirmed (non-nil) write; `finish()` is now idempotent (`guard panel != nil`).
- **F7** — fixed. `willTerminateNotification` observer flushes the open draft (`saveNow`) on ⌘Q.
- **F9, F10, F11, F12** — fixed. Settings vault/subfolder I/O cached in `@State` (single read); draft and note writes moved off the main actor (`DraftStore.io` serial queue; `persist()` `Task.detached`).
- **F13** — fixed. Stub deleted.
- **F14** — fixed. Deterministic `.path` tiebreaker; covered by the `equalTimestampsSortDeterministicallyByPath` test.
- **F6** — resolved + **accepted**. The shortcuts surface now shows only the wired shortcuts (⌘1/2/3, ⌘B, ⌘I). Wiring the broader formatting set is a possible future extension; considered complete for now.
- **F4** — **won't fix (by design)**. Committing & closing on *any* focus loss (⌘-Tab, opening Settings, click-away) is the intended capture-and-forget behavior — not just click-away. Do not "fix" or re-flag.
- **F5** — **verified working**. Manual test confirms Esc closes the window and saves the note as expected; `NSTextView` does not swallow it.
- **F8** — **accepted as-is**. A retry-once focus path was added and works in practice; switching to a MarkdownEngine focus API remains an optional future hardening.

---

## Priority 1 — Data loss / duplication (fix first; all CONFIRMED)

### F1. `commit()` clears the draft even when the note wasn't persisted → typed note lost
`fecni/AppCoordinator.swift:34`
```swift
func commit(markdown: String) {
    defer { draftStore.clear() }                 // runs even on the guard-return / failed write
    guard let dir = settings.resolvedDirectory else { return }
    _ = try? CaptureStore(directory: dir).write(markdown: markdown, at: Date())
}
```
**Repro:** No vault configured (fresh install, or vault later cleared) — or vault folder unmounted/deleted so `write` throws (swallowed by `try?`). User types a note → Esc → `commit()` returns early / write fails → the deferred `draftStore.clear()` deletes the autosaved draft → the text is gone with no feedback.
**Fix:** Only `clear()` after a *confirmed* successful write. e.g. capture the result: `guard let dir = …; if let _ = try? store.write(…) { draftStore.clear() }`. If there's no vault, keep the draft (and ideally surface "set a vault" to the user). Consider not swallowing the write error (log/notify).

### F2. `recoverDraftIfPresent()` clears the draft even if the recovery write fails → crash-recovered note lost
`fecni/AppCoordinator.swift:43`
```swift
private func recoverDraftIfPresent() {
    guard let recovered = draftStore.load(), let dir = settings.resolvedDirectory else { return }
    _ = try? CaptureStore(directory: dir).write(markdown: recovered, at: Date())
    draftStore.clear()                           // unconditional, even if write threw
}
```
**Repro:** App crashed mid-note → `draft.md` exists → next launch the vault path is set but unreachable → `write` throws → `try?` swallows → `clear()` deletes the draft → recovered note lost.
**Fix:** Only `clear()` when the write returned a non-nil URL (success). Same pattern as F1 — factor a single "persist note, clear draft only on success" helper used by both paths.

### F3. `finish()` has no idempotency guard → double-dismiss writes the note twice
`fecni/CapturePanelController.swift:64`
```swift
private func finish(markdown: String) {
    coordinator.commit(markdown: markdown)       // no guard against being called twice
    panel?.delegate = nil
    panel?.close()
    panel = nil
    model = nil
}
```
**Repro:** `requestDismiss()` is reachable from both `CaptureView.onExitCommand` (Esc) and `windowDidResignKey` (click-away). If Esc and key-loss land in the same runloop batch before teardown, both reach `onDismiss → finish()` → `commit()` runs twice → two duplicate `.md` files for one note. (The `delegate = nil`-before-`close()` ordering guards the close→resign path, but not a genuine double-trigger.)
**Fix:** Guard at the top: `guard panel != nil else { return }` (or an `isFinishing` flag).

---

## Priority 2 — Behavior (real, but needs a UX decision before changing)

### F4. `windowDidResignKey` commits & closes on ANY key loss — ⌘-Tab away, opening Settings — not just click-away  ·  CONFIRMED
`fecni/CapturePanelController.swift:60`
```swift
func windowDidResignKey(_ notification: Notification) {
    model?.requestDismiss()                      // also fires on app deactivation / Settings open
}
```
**Repro:** Mid-note, the user ⌘-Tabs to look something up (or opens Settings) → panel resigns key → the partial note is committed and the panel destroyed; returning, the capture is gone and a half-written note is already saved.
**Decision needed:** how aggressive should "click-away saves" be? Options: (a) ignore dismissal when the app is merely deactivated (only dismiss on a click into another window of a still-active app); (b) on resign-key, *hide & keep* the panel + draft instead of committing; (c) keep current behavior. Tie-break with the intended capture UX.

### F5. Esc may be swallowed by MarkdownEngine's `NSTextView` so `.onExitCommand` never fires  ·  PLAUSIBLE (needs a run)
`fecni/CaptureView.swift` (the `.onExitCommand { model.requestDismiss() }` modifier)
**Repro:** With the cursor in the editor, the `NSTextView` may consume Esc (autocomplete/IME/cancel) before SwiftUI's `.onExitCommand` sees it → the documented "Esc saves & closes" gesture does nothing; only click-away works. Unverified since the MarkdownEngine pivot.
**Decision/next step:** verify on a run. If swallowed, intercept Esc at the AppKit level (e.g. a `keyDown`/`cancelOperation(_:)` hook on the panel or a `commands`/key handler that doesn't depend on `.onExitCommand`).

---

## Priority 3 — Robustness, efficiency, cleanup

### F6. Shortcuts footer advertises 7 formatting shortcuts that are not wired  ·  CONFIRMED (misleading UI)
`fecni/ShortcutsFooter.swift:5` — lists ⌘B/⌘I/⌘1–3/⌘E/⌘L/⇧⌘U/⇧⌘O, but the command layer (`EditorFormatting.swift`) was removed in the MarkdownEngine pivot and never re-wired. Users try the shortcuts and nothing happens.
**Fix:** Either wire the formatting commands (see "Cross-cutting" below) or remove/caveat the footer until they exist.

### F7. Quitting with a capture window open loses the in-progress note  ·  PLAUSIBLE
`fecni/fecniApp.swift` (Quit button) / no terminate hook. ⌘Q (or termination) within ~1.5s of typing → neither the debounced draft write nor `commit()` has run → note gone.
**Fix:** Flush on terminate — e.g. `applicationWillTerminate` (or a `NSApplication.willTerminateNotification` observer) that commits the open capture / `saveNow` the draft.

### F8. Initial-focus mechanism is fragile  ·  CONFIRMED (fragility) / PLAUSIBLE (silent miss)
`fecni/CapturePanelController.swift:44,51` — `firstTextView` recursively walks MarkdownEngine's private view hierarchy one runloop tick after `present()`. If MarkdownEngine changes its view tree, or layout isn't done within one tick on a cold launch, focus is silently skipped.
**Fix:** Prefer a focus hook MarkdownEngine offers (check the package for an autofocus/first-responder API or a `@FocusState` bridge); if none, retry once on the next layout pass and/or pin the dependency version. Currently works in practice.

### F9. `SettingsView` scans the vault directory inside the view body on every render  ·  CONFIRMED (wasted main-thread I/O)
`fecni/SettingsView.swift:23` — `ForEach(VaultLocator.subfolders(ofVault: path), …)` calls `contentsOfDirectory` synchronously on each body evaluation.
**Fix:** Compute subfolders into `@State` (refresh on vault change / onAppear), like `vaults` already is.

### F10. `DraftStore` writes the draft on the main queue  ·  CONFIRMED (main-thread I/O)
`fecni/DraftStore.swift:21` — `DispatchQueue.main.asyncAfter(…) { try? markdown.write(…) }` does synchronous disk I/O on the main thread every ~1.5s while typing. Notes are tiny so impact is small, but it can jank on slow/contended disks (iCloud).
**Fix:** Run the write on a background queue / `Task.detached`; keep only scheduling on the main actor.

### F11. `commit()` / `recoverDraftIfPresent()` do blocking file I/O on the MainActor (incl. at launch)  ·  CONFIRMED (main-thread I/O)
`fecni/AppCoordinator.swift:36,42` — `CaptureStore.write` (dir scan + atomic write) runs synchronously on the main actor; recovery runs during `init`.
**Fix:** Move file I/O off the main actor (async). Low impact for tiny notes but tidy alongside F10.

### F12. `detectedVaults()` read twice per Settings open  ·  CONFIRMED (redundant I/O)
`fecni/SettingsView.swift:7,37` — `@State` initializer reads + decodes `obsidian.json`, then `onAppear` reads it again unconditionally.
**Fix:** Keep one (onAppear refresh) or guard the onAppear refresh.

### F13. `CaptureKit.swift` is a comment-only stub  ·  LOW (dead code)
`Packages/CaptureKit/Sources/CaptureKit/CaptureKit.swift:1` — leftover scaffold; delete it.

### F14. Vault sort is not stable for equal `ts`  ·  LOW
`Packages/CaptureKit/Sources/CaptureKit/VaultLocator.swift:27` — `sorted { ($0.lastOpened ?? .distantPast) > … }` is unstable; two vaults with identical `ts` can reorder across launches.
**Fix:** Add a deterministic tiebreaker (e.g. `.path`).

---

## Cross-cutting: the formatting commands are unwired

F6 (and the original spec's ⌘B/⌘I/⌘1–3/⌘L/⇧⌘U/⇧⌘O set) have no implementation since the MarkdownEngine pivot removed `EditorFormatting.swift`/`NoteFormatter`. The intended next feature is to wire these against MarkdownEngine's command hooks — note its `NativeTextViewWrapper` exposes a `pendingInlineReplacement: Binding<InlineReplacementRequest?>` and list input handling, which look like the intended mechanism. Until then, F6 should be resolved by hiding/caveating the footer.

---

## Refuted candidates (considered, dismissed — do not re-chase)

- **GCD cancel race / "phantom draft re-written after clear()"** — REFUTED. `scheduleSave` work item and `clear()` both run on the **main** queue (serialized); `cancel()` before the deadline is honored, so the write is skipped. No concurrency window.
- **`CaptureStore` concurrent-write TOCTOU / same-filename overwrite** — REFUTED as reachable. All writes go through `commit()` on the MainActor (serialized); two captures in the same minute are sequential and the second sees the first's file → ` 2` suffix works. Not triggerable without true concurrency, which doesn't exist here.
- **`SettingsStore` `@unchecked Sendable` UserDefaults data race** — REFUTED. `UserDefaults` is documented thread-safe, and access is MainActor-bound in practice.
- **`CaptureStore` trailing-slash `directory.path` breaks collision matching** — REFUTED. `contentsOfDirectory(atPath:)` returns bare filenames regardless of trailing slash; comparison is against bare `"\(base).md"`.
- **`resolvedDirectory` path traversal via `subfolder` containing `../`** — not reachable: `subfolder` is sourced from `VaultLocator.subfolders` (single path components) or the manual folder picker; no UI path supplies `../`. (Could add normalization as defense-in-depth, but not a live bug.)
- **`vaultBinding` resets subfolder on every re-render** — REFUTED. SwiftUI `Picker` calls the setter only on user selection change, not on render. Resetting subfolder when the *vault* changes is intended (a subfolder of vault A doesn't exist in vault B). Minor edge: re-selecting the same vault clears subfolder — low.
- **`CaptureStoreTests` empty-skip assertion vacuous** — minor; the primary assertion (`write(...) == nil`) is solid.
- **`@unchecked Sendable` on `CaptureStore`'s `DateFormatter`** — not a live bug (writes are MainActor-serialized; formatter never used concurrently).

---

## Suggested fix order for the next session

1. **F1 + F2** (data loss) — factor a "persist, clear draft only on success" path; keep the draft when no vault.
2. **F3** (duplicate files) — add the `finish()` guard.
3. **F10 + F11** (main-thread I/O) — move file writes off the main actor.
4. **F9 + F12** (Settings I/O) — cache subfolders in `@State`, de-dup the vaults read.
5. **F6 / formatting commands** — decide: wire the shortcuts (resolves the footer) or hide the footer.
6. **F4 + F5** — decide dismissal UX, verify Esc on a run.
7. **F13, F14, F7, F8** — cleanup / hardening.
