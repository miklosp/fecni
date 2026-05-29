import AppKit
import SwiftUI

/// Presents a fresh capture panel on demand and commits the note when the panel
/// loses key focus (click-away) or the editor requests dismissal (Esc).
@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate {
    private let coordinator: AppCoordinator
    private var panel: CapturePanel?
    private var model: CaptureModel?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    func present() {
        // A capture already open: just refocus it.
        if let panel {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            return
        }

        let model = CaptureModel(draftStore: coordinator.draftStore) { [weak self] markdown in
            self?.finish(markdown: markdown)
        }
        self.model = model

        let panel = CapturePanel()
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: CaptureView(model: model))
        panel.center()
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    /// Click-away: losing key focus saves & closes.
    func windowDidResignKey(_ notification: Notification) {
        model?.requestDismiss()
    }

    private func finish(markdown: String) {
        coordinator.commit(markdown: markdown)
        panel?.delegate = nil
        panel?.close()
        panel = nil
        model = nil
    }
}
