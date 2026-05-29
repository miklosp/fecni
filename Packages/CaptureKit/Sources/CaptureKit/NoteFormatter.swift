import Foundation

/// Pure, UI-free formatting operations on the editor's `AttributedString`.
///
/// The app layer converts an `AttributedTextSelection` into the ranges / coverage
/// these functions take, then calls them. Everything here is plain Foundation,
/// so it is fully testable via `swift test` (the app-hosted XCTest harness is
/// unreliable on the current toolchain — see the design spec's open notes).
public enum NoteFormatter {

    /// Toggles an inline intent (bold/italic/code) over each non-empty range.
    public static func toggleInline(
        _ intent: InlinePresentationIntent,
        over ranges: [Range<AttributedString.Index>],
        in text: inout AttributedString
    ) {
        for range in ranges where !range.isEmpty {
            let current = text[range].inlinePresentationIntent ?? []
            let updated = current.contains(intent) ? current.subtracting(intent) : current.union(intent)
            text[range].inlinePresentationIntent = updated.isEmpty ? nil : updated
        }
    }

    /// The full paragraph range enclosing `coverage`, expanded to the nearest
    /// newline boundaries.
    public static func paragraphRange(
        covering coverage: Range<AttributedString.Index>,
        in text: AttributedString
    ) -> Range<AttributedString.Index> {
        let chars = text.characters
        var start = coverage.lowerBound
        while start > chars.startIndex {
            let prev = chars.index(before: start)
            if chars[prev] == "\n" { break }
            start = prev
        }
        var end = coverage.upperBound
        while end < chars.endIndex, chars[end] != "\n" {
            end = chars.index(after: end)
        }
        return start..<end
    }

    /// Applies a caller-built block `PresentationIntent` to the paragraph(s)
    /// enclosing `coverage`. `taskChecked` sets (or, when nil, clears) the GFM
    /// task-item state on the same span.
    public static func applyBlock(
        _ intent: PresentationIntent,
        taskChecked: Bool?,
        toParagraphsCovering coverage: Range<AttributedString.Index>,
        in text: inout AttributedString
    ) {
        let para = paragraphRange(covering: coverage, in: text)
        text[para].presentationIntent = intent
        text[para][TaskItemAttribute.self] = taskChecked
    }
}
