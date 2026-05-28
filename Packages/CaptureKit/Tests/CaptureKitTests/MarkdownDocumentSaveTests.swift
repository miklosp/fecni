import Testing
import Foundation
@testable import CaptureKit

@Test func savesHeading() {
    var a = AttributedString("Title")
    a.presentationIntent = PresentationIntent(.header(level: 1), identity: 1, parent: nil)
    #expect(MarkdownDocument.markdown(from: a) == "# Title\n")
}

@Test func savesBoldItalicCode() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "a **b** _c_ `d`")
    #expect(MarkdownDocument.markdown(from: a) == "a **b** *c* `d`\n")
}

@Test func savesUnorderedList() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "- one\n- two")
    #expect(MarkdownDocument.markdown(from: a) == "- one\n- two\n")
}

@Test func savesTaskList() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "- [ ] todo\n- [x] done")
    #expect(MarkdownDocument.markdown(from: a) == "- [ ] todo\n- [x] done\n")
}

@Test func savesCodeBlock() {
    let a = MarkdownDocument.attributedString(fromMarkdown: "```\nlet x = 1\n```")
    #expect(MarkdownDocument.markdown(from: a) == "```\nlet x = 1\n```\n")
}
