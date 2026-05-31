import SwiftUI
import KeyboardShortcuts
import CaptureKit

/// Composition root: owns settings, the capture-panel controller, the draft
/// store, and the global-hotkey registration.
@MainActor
@Observable
final class AppCoordinator {
    var settings: CaptureSettings
    private let settingsStore = SettingsStore()
    @ObservationIgnored let draftStore = DraftStore()
    @ObservationIgnored private lazy var panelController = CapturePanelController(coordinator: self)

    init() {
        settings = settingsStore.load()
        KeyboardShortcuts.onKeyUp(for: .openCapture) { [weak self] in
            Task { @MainActor in self?.openCapture() }
        }
        recoverDraftIfPresent()
    }

    func openCapture() {
        panelController.present()
    }

    func updateSettings(_ new: CaptureSettings) {
        settings = new
        settingsStore.save(new)
    }

    /// Called by the panel controller when the editor dismisses.
    func commit(markdown: String) {
        // Nothing typed: drop any leftover draft and stop.
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            draftStore.clear()
            return
        }
        // No vault configured: keep the draft so the note isn't lost.
        guard let dir = settings.resolvedDirectory else { return }
        persist(markdown: markdown, to: dir)
    }

    /// If a draft survived a crash, write it out as a recovered note on launch.
    private func recoverDraftIfPresent() {
        guard let recovered = draftStore.load(), let dir = settings.resolvedDirectory else { return }
        persist(markdown: recovered, to: dir)
    }

    /// Writes the note to the vault off the main actor, then clears the draft
    /// only after a confirmed successful write. A failed write (e.g. vault
    /// unreachable) leaves the draft in place so the text survives to the next
    /// launch's recovery.
    private func persist(markdown: String, to dir: URL) {
        let draftStore = self.draftStore
        Task.detached {
            // `try?` flattens to a nil URL when the write throws (or the content
            // was empty, which callers already exclude). A non-nil URL means the
            // file landed on disk — only then is it safe to drop the draft.
            if (try? CaptureStore(directory: dir).write(markdown: markdown, at: Date())) != nil {
                await draftStore.clear()
            }
        }
    }
}
