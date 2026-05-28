import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global shortcut that opens the capture window. Default: ⌃⌥Space.
    static let openCapture = Self("openCapture", default: .init(.space, modifiers: [.control, .option]))
}
