import Testing
@testable import CaptureKit

private func roundTrips(_ markdown: String) -> Bool {
    let once = MarkdownDocument.markdown(from: MarkdownDocument.attributedString(fromMarkdown: markdown))
    let twice = MarkdownDocument.markdown(from: MarkdownDocument.attributedString(fromMarkdown: once))
    return once == twice   // idempotent after first normalization
}

@Test(arguments: [
    "# Heading 1\n",
    "## Heading 2\n",
    "### Heading 3\n",
    "Plain paragraph text.\n",
    "Text with **bold** and *italic* and `code`.\n",
    "A [link](https://example.com) inline.\n",
    "- one\n- two\n- three\n",
    "1. first\n2. second\n",
    "- [ ] open task\n- [x] done task\n",
    "```\nlet x = 1\nlet y = 2\n```\n",
])
func canonicalMarkdownIsStableAcrossRoundTrips(_ sample: String) {
    #expect(roundTrips(sample), "not idempotent: \(sample)")
}

@Test func multiBlockDocumentRoundTrips() {
    let doc = """
    # Title

    Intro paragraph with **bold**.

    - first
    - second

    ```
    code here
    ```
    """
    #expect(roundTrips(doc))
}
