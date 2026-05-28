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
        defer { draftStore.clear() }
        guard let dir = settings.resolvedDirectory else { return }
        _ = try? CaptureStore(directory: dir).write(markdown: markdown, at: Date())
    }

    /// If a draft survived a crash, write it out as a recovered note on launch.
    private func recoverDraftIfPresent() {
        guard let recovered = draftStore.load(), let dir = settings.resolvedDirectory else { return }
        _ = try? CaptureStore(directory: dir).write(markdown: recovered, at: Date())
        draftStore.clear()
    }
}
