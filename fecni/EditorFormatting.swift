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

/// Mutates the editor's `AttributedString` to apply the supported formats.
/// Inline formats toggle over the selection; block formats apply to the
/// paragraph(s) the selection/cursor sits in.
enum Formatter {
    private static var identityCounter = 1000
    private static func nextIdentity() -> Int { identityCounter += 1; return identityCounter }

    // MARK: Inline

    static func toggleInline(_ intent: InlinePresentationIntent, in model: CaptureModel) {
        let ranges = selectedRanges(in: model)
        guard !ranges.isEmpty else { return }
        for range in ranges {
            let current = model.text[range].inlinePresentationIntent ?? []
            let updated = current.contains(intent) ? current.subtracting(intent) : current.union(intent)
            model.text[range].inlinePresentationIntent = updated.isEmpty ? nil : updated
        }
    }

    // MARK: Block

    static func setHeading(_ level: Int, in model: CaptureModel) {
        applyBlockIntent(in: model) {
            PresentationIntent(.header(level: level), identity: nextIdentity(), parent: nil)
        }
        clearTaskItem(in: model)
    }

    static func toggleCodeBlock(in model: CaptureModel) {
        applyBlockIntent(in: model) {
            PresentationIntent(.codeBlock(languageHint: nil), identity: nextIdentity(), parent: nil)
        }
        clearTaskItem(in: model)
    }

    static func toggleList(_ kind: PresentationIntent.Kind, in model: CaptureModel) {
        applyBlockIntent(in: model) {
            let list = PresentationIntent(kind, identity: nextIdentity(), parent: nil)
            return PresentationIntent(.listItem(ordinal: 1), identity: nextIdentity(), parent: list)
        }
        clearTaskItem(in: model)
    }

    static func toggleTaskList(in model: CaptureModel) {
        applyBlockIntent(in: model) {
            let list = PresentationIntent(.unorderedList, identity: nextIdentity(), parent: nil)
            return PresentationIntent(.listItem(ordinal: 1), identity: nextIdentity(), parent: list)
        }
        for range in paragraphRanges(in: model) {
            model.text[range][TaskItemAttribute.self] = false
        }
    }

    private static func applyBlockIntent(in model: CaptureModel, _ make: () -> PresentationIntent) {
        for range in paragraphRanges(in: model) {
            model.text[range].presentationIntent = make()
        }
    }

    private static func clearTaskItem(in model: CaptureModel) {
        for range in paragraphRanges(in: model) {
            model.text[range][TaskItemAttribute.self] = nil
        }
    }

    // MARK: Paste link

    /// If the pasteboard holds a URL and there is a non-empty selection, wraps the
    /// selection as a link and returns true. Otherwise returns false (caller lets
    /// the default paste insert the bare URL).
    static func pasteLink(in model: CaptureModel) -> Bool {
        guard let raw = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw), url.scheme != nil else { return false }
        let ranges = selectedRanges(in: model)
        guard let first = ranges.first, !first.isEmpty else { return false }
        for range in ranges { model.text[range].link = url }
        return true
    }

    // MARK: Selection helpers

    private static func selectedRanges(in model: CaptureModel) -> [Range<AttributedString.Index>] {
        switch model.selection.indices(in: model.text) {
        case .insertionPoint: return []
        case .ranges(let set): return Array(set.ranges)
        @unknown default: return []
        }
    }

    /// The full paragraph range(s) the selection or cursor sits in, expanded to
    /// the nearest newline boundaries.
    private static func paragraphRanges(in model: CaptureModel) -> [Range<AttributedString.Index>] {
        let text = model.text
        let chars = text.characters
        let lo: AttributedString.Index
        let hi: AttributedString.Index
        switch model.selection.indices(in: text) {
        case .insertionPoint(let i): lo = i; hi = i
        case .ranges(let set):
            guard let first = set.ranges.first, let last = set.ranges.last else { return [] }
            lo = first.lowerBound; hi = last.upperBound
        @unknown default: return []
        }

        var start = lo
        while start > chars.startIndex {
            let prev = chars.index(before: start)
            if chars[prev] == "\n" { break }
            start = prev
        }
        var end = hi
        while end < chars.endIndex, chars[end] != "\n" {
            end = chars.index(after: end)
        }
        return [start..<end]
    }
}
