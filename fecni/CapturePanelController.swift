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

        // Put the cursor in the editor so you can type immediately. The text view
        // is created by NativeTextViewWrapper after the hosting view lays out, so
        // defer to the next runloop tick.
        DispatchQueue.main.async { [weak panel] in
            guard let panel, let content = panel.contentView,
                  let textView = Self.firstTextView(in: content) else { return }
            panel.makeFirstResponder(textView)
        }
    }

    private static func firstTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView { return textView }
        for subview in view.subviews {
            if let found = firstTextView(in: subview) { return found }
        }
        return nil
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
