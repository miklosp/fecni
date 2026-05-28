import Testing
import Foundation
@testable import CaptureKit

@Test func loadParsesHeadingLevel() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "## Title")
    let run = a.runs.first { $0.presentationIntent != nil }
    let kinds = run?.presentationIntent?.components.map(\.kind) ?? []
    #expect(kinds.contains { if case .header(let l) = $0 { return l == 2 } else { return false } })
    #expect(String(a.characters).contains("Title"))
}

@Test func loadParsesBoldAndItalicInline() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "a **b** _c_")
    let bold = a.runs.first { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
    let italic = a.runs.first { $0.inlinePresentationIntent?.contains(.emphasized) == true }
    #expect(bold != nil)
    #expect(italic != nil)
}

@Test func loadParsesTaskItemsWithCheckedState() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "- [ ] todo\n- [x] done")
    let states = a.runs.compactMap { $0[TaskItemAttribute.self] }
    #expect(states.contains(false))
    #expect(states.contains(true))
    // The "[ ]" / "[x]" literals must NOT survive into the text.
    #expect(!String(a.characters).contains("[ ]"))
    #expect(!String(a.characters).contains("[x]"))
}

@Test func loadParsesLink() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "see [docs](https://example.com)")
    let link = a.runs.first { $0.link != nil }?.link
    #expect(link?.absoluteString == "https://example.com")
}
