import SwiftUI
import CaptureKit

/// Maps the editor's keyboard shortcuts to formatting commands.
///
/// NOTE: command routing through SwiftUI's rich-text `TextEditor` is the area
/// most likely to need adjustment once run on-device — `TextEditor` may consume
/// ⌘B/⌘I (applying its own emphasis) and ⌘V (default paste) before this handler
/// sees them. Block commands (⌘1/2/3, ⌘L, ⇧⌘U/O, ⌘E) should reach here.
struct EditorCommands: ViewModifier {
    @Bindable var model: CaptureModel

    func body(content: Content) -> some View {
        content.onKeyPress(phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            let shift = press.modifiers.contains(.shift)
            let key = Character(String(press.key.character).lowercased())

            switch (key, shift) {
            case ("b", false): Formatter.toggleInline(.stronglyEmphasized, in: model); return .handled
            case ("i", false): Formatter.toggleInline(.emphasized, in: model); return .handled
            case ("e", false): Formatter.toggleCodeBlock(in: model); return .handled
            case ("l", false): Formatter.toggleTaskList(in: model); return .handled
            case ("1", false): Formatter.setHeading(1, in: model); return .handled
            case ("2", false): Formatter.setHeading(2, in: model); return .handled
            case ("3", false): Formatter.setHeading(3, in: model); return .handled
            case ("u", true):  Formatter.toggleList(.unorderedList, in: model); return .handled
            case ("o", true):  Formatter.toggleList(.orderedList, in: model); return .handled
            case ("v", false): return Formatter.pasteLink(in: model) ? .handled : .ignored
            default: return .ignored
            }
        }
    }
}

/// Thin glue: turns the editor's `AttributedTextSelection` into the ranges /
/// coverage that `CaptureKit.NoteFormatter` operates on, builds the block
/// `PresentationIntent`s, and applies them. All mutation logic lives in
/// `NoteFormatter` (unit-tested via `swift test`).
enum Formatter {
    private static var identityCounter = 1000
    private static func nextIdentity() -> Int { identityCounter += 1; return identityCounter }

    // MARK: Inline

    static func toggleInline(_ intent: InlinePresentationIntent, in model: CaptureModel) {
        NoteFormatter.toggleInline(intent, over: selectionRanges(in: model), in: &model.text)
    }

    // MARK: Block

    static func setHeading(_ level: Int, in model: CaptureModel) {
        applyBlock(in: model) {
            PresentationIntent(.header(level: level), identity: nextIdentity(), parent: nil)
        }
    }

    static func toggleCodeBlock(in model: CaptureModel) {
        applyBlock(in: model) {
            PresentationIntent(.codeBlock(languageHint: nil), identity: nextIdentity(), parent: nil)
        }
    }

    static func toggleList(_ kind: PresentationIntent.Kind, in model: CaptureModel) {
        applyBlock(in: model) {
            let list = PresentationIntent(kind, identity: nextIdentity(), parent: nil)
            return PresentationIntent(.listItem(ordinal: 1), identity: nextIdentity(), parent: list)
        }
    }

    static func toggleTaskList(in model: CaptureModel) {
        applyBlock(in: model, taskChecked: false) {
            let list = PresentationIntent(.unorderedList, identity: nextIdentity(), parent: nil)
            return PresentationIntent(.listItem(ordinal: 1), identity: nextIdentity(), parent: list)
        }
    }

    private static func applyBlock(
        in model: CaptureModel,
        taskChecked: Bool? = nil,
        _ make: () -> PresentationIntent
    ) {
        guard let coverage = coverage(in: model) else { return }
        NoteFormatter.applyBlock(make(), taskChecked: taskChecked, toParagraphsCovering: coverage, in: &model.text)
    }

    // MARK: Paste link

    /// If the pasteboard holds a URL and there is a non-empty selection, wraps the
    /// selection as a link and returns true. Otherwise returns false (caller lets
    /// the default paste insert the bare URL).
    static func pasteLink(in model: CaptureModel) -> Bool {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw), url.scheme != nil else { return false }
        let ranges = selectionRanges(in: model)
        guard let first = ranges.first, !first.isEmpty else { return false }
        for range in ranges { model.text[range].link = url }
        return true
    }

    // MARK: Selection → ranges glue

    private static func selectionRanges(in model: CaptureModel) -> [Range<AttributedString.Index>] {
        switch model.selection.indices(in: model.text) {
        case .insertionPoint: return []
        case .ranges(let set): return Array(set.ranges)
        @unknown default: return []
        }
    }

    private static func coverage(in model: CaptureModel) -> Range<AttributedString.Index>? {
        switch model.selection.indices(in: model.text) {
        case .insertionPoint(let i): return i..<i
        case .ranges(let set):
            guard let first = set.ranges.first, let last = set.ranges.last else { return nil }
            return first.lowerBound..<last.upperBound
        @unknown default: return nil
        }
    }
}
