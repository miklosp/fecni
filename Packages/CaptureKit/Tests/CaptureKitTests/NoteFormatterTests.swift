import Testing
import Foundation
@testable import CaptureKit

/// These exercise the exact formatting logic that crashed only in the broken
/// app-hosted test harness — here it runs under `swift test`.

@Test func boldOverRangeSerializes() {
    var text = AttributedString("hello")
    NoteFormatter.toggleInline(.stronglyEmphasized, over: [text.startIndex..<text.endIndex], in: &text)
    #expect(MarkdownDocument.markdown(from: text) == "**hello**\n")
}

@Test func italicOverRangeSerializes() {
    var text = AttributedString("hello")
    NoteFormatter.toggleInline(.emphasized, over: [text.startIndex..<text.endIndex], in: &text)
    #expect(MarkdownDocument.markdown(from: text) == "*hello*\n")
}

@Test func inlineTogglesOff() {
    var text = AttributedString("hello")
    NoteFormatter.toggleInline(.stronglyEmphasized, over: [text.startIndex..<text.endIndex], in: &text)
    NoteFormatter.toggleInline(.stronglyEmphasized, over: [text.startIndex..<text.endIndex], in: &text)
    #expect(MarkdownDocument.markdown(from: text) == "hello\n")
}

@Test func headingAppliesToParagraph() {
    var text = AttributedString("Title")
    let intent = PresentationIntent(.header(level: 2), identity: 1, parent: nil)
    NoteFormatter.applyBlock(intent, taskChecked: nil, toParagraphsCovering: text.startIndex..<text.endIndex, in: &text)
    #expect(MarkdownDocument.markdown(from: text) == "## Title\n")
}

@Test func unorderedListItem() {
    var text = AttributedString("item")
    let list = PresentationIntent(.unorderedList, identity: 1, parent: nil)
    let item = PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: list)
    NoteFormatter.applyBlock(item, taskChecked: nil, toParagraphsCovering: text.startIndex..<text.endIndex, in: &text)
    #expect(MarkdownDocument.markdown(from: text) == "- item\n")
}

@Test func taskListItem() {
    var text = AttributedString("do it")
    let list = PresentationIntent(.unorderedList, identity: 1, parent: nil)
    let item = PresentationIntent(.listItem(ordinal: 1), identity: 2, parent: list)
    NoteFormatter.applyBlock(item, taskChecked: false, toParagraphsCovering: text.startIndex..<text.endIndex, in: &text)
    #expect(MarkdownDocument.markdown(from: text) == "- [ ] do it\n")
}

@Test func codeBlockApplies() {
    var text = AttributedString("let x = 1")
    let intent = PresentationIntent(.codeBlock(languageHint: nil), identity: 1, parent: nil)
    NoteFormatter.applyBlock(intent, taskChecked: nil, toParagraphsCovering: text.startIndex..<text.endIndex, in: &text)
    #expect(MarkdownDocument.markdown(from: text) == "```\nlet x = 1\n```\n")
}

@Test func paragraphRangeExpandsToEnclosingLine() {
    let text = AttributedString("one\ntwo\nthree")
    let inside = text.index(text.startIndex, offsetByCharacters: 5)  // inside "two"
    let range = NoteFormatter.paragraphRange(covering: inside..<inside, in: text)
    #expect(String(text[range].characters) == "two")
}
