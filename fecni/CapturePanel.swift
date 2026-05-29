import AppKit

/// A borderless-feeling floating panel that can become key (so it accepts text
/// input), appears on the active Space, and floats above full-screen apps.
final class CapturePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 380),
            styleMask: [.titled, .fullSizeContentView, .resizable, .closable],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        level = .floating
        // .canJoinAllSpaces and .moveToActiveSpace are mutually exclusive — AppKit
        // throws if both are set. .canJoinAllSpaces shows the panel on whichever
        // Space is active when summoned; .fullScreenAuxiliary floats it over
        // full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
