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
        // Quitting (⌘Q) within the draft autosave debounce window would lose an
        // in-progress note; flush it synchronously on terminate so the next
        // launch recovers it.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.flushOpenDraft() }
        }
    }

    private func flushOpenDraft() {
        guard let model else { return }
        coordinator.draftStore.saveNow(model.text)
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
        focusEditor(in: panel, retriesRemaining: 1)
    }

    /// Focuses MarkdownEngine's text view once it exists in the panel's view
    /// tree. On a cold launch the view may not be built within a single tick,
    /// so retry once on the next pass before giving up.
    private func focusEditor(in panel: CapturePanel, retriesRemaining: Int) {
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let panel else { return }
            if let content = panel.contentView,
               let textView = Self.firstTextView(in: content) {
                panel.makeFirstResponder(textView)
            } else if retriesRemaining > 0 {
                self?.focusEditor(in: panel, retriesRemaining: retriesRemaining - 1)
            }
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
        // Esc and click-away can both land before teardown; commit at most once.
        guard panel != nil else { return }
        coordinator.commit(markdown: markdown)
        panel?.delegate = nil
        panel?.close()
        panel = nil
        model = nil
    }
}
