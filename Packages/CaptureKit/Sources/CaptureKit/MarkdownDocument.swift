import Foundation
import Markdown

public enum MarkdownDocument {

    // MARK: - Load: Markdown -> AttributedString

    public static func attributedString(fromMarkdown markdown: String) -> AttributedString {
        let document = Document(parsing: markdown)
        var builder = AttributedString()
        var identity = 0
        func nextIdentity() -> Int { identity += 1; return identity }

        var firstBlock = true
        for block in document.blockChildren {
            if !firstBlock { builder.append(AttributedString("\n")) }
            firstBlock = false
            appendBlock(block, listContext: nil, checked: nil, into: &builder, nextIdentity: nextIdentity)
        }
        return builder
    }

    /// `listContext` is the `PresentationIntent` of the enclosing list item (if any),
    /// used as the `parent` of the block's own intent so nesting is expressed via the
    /// parent chain that Foundation flattens into `.components`.
    /// `checked` is the task-item state for the current list item, if any.
    private static func appendBlock(
        _ markup: Markup,
        listContext: PresentationIntent?,
        checked: Bool?,
        into builder: inout AttributedString,
        nextIdentity: () -> Int
    ) {
        switch markup {
        case let heading as Heading:
            let intent = PresentationIntent(.header(level: heading.level),
                                            identity: nextIdentity(), parent: listContext)
            appendInlineChildren(of: heading, blockIntent: intent, checked: checked, into: &builder)

        case let paragraph as Paragraph:
            let intent = PresentationIntent(.paragraph,
                                            identity: nextIdentity(), parent: listContext)
            appendInlineChildren(of: paragraph, blockIntent: intent, checked: checked, into: &builder)

        case let code as CodeBlock:
            let intent = PresentationIntent(.codeBlock(languageHint: code.language),
                                            identity: nextIdentity(), parent: listContext)
            var run = AttributedString(code.code.hasSuffix("\n") ? String(code.code.dropLast()) : code.code)
            run.presentationIntent = intent
            builder.append(run)

        case let list as UnorderedList:
            appendListItems(list.listItems, listKind: .unorderedList,
                            listContext: listContext, into: &builder, nextIdentity: nextIdentity)

        case let list as OrderedList:
            appendListItems(list.listItems, listKind: .orderedList,
                            listContext: listContext, into: &builder, nextIdentity: nextIdentity)

        default:
            let intent = PresentationIntent(.paragraph,
                                            identity: nextIdentity(), parent: listContext)
            var run = AttributedString(markup.format())
            run.presentationIntent = intent
            builder.append(run)
        }
    }

    private static func appendListItems(
        _ items: some Sequence<ListItem>,
        listKind: PresentationIntent.Kind,
        listContext: PresentationIntent?,
        into builder: inout AttributedString,
        nextIdentity: () -> Int
    ) {
        var ordinal = 1
        var first = true
        for item in items {
            if !first { builder.append(AttributedString("\n")) }
            first = false
            // Build the parent chain: list -> listItem, with any outer list as ancestor.
            let listIntent = PresentationIntent(listKind, identity: nextIdentity(), parent: listContext)
            let itemIntent = PresentationIntent(.listItem(ordinal: ordinal),
                                                identity: nextIdentity(), parent: listIntent)
            let checked: Bool? = item.checkbox.map { $0 == .checked }
            var firstChild = true
            for child in item.blockChildren {
                if !firstChild { builder.append(AttributedString("\n")) }
                firstChild = false
                appendBlock(child, listContext: itemIntent, checked: checked,
                            into: &builder, nextIdentity: nextIdentity)
            }
            ordinal += 1
        }
    }

    private static func appendInlineChildren(
        of markup: Markup,
        blockIntent: PresentationIntent,
        checked: Bool?,
        into builder: inout AttributedString
    ) {
        let children = Array(markup.children)
        for inline in children {
            var fragment = inlineAttributedString(inline)
            fragment.presentationIntent = blockIntent
            if let checked { fragment[TaskItemAttribute.self] = checked }
            builder.append(fragment)
        }
        if children.isEmpty {
            var empty = AttributedString("")
            empty.presentationIntent = blockIntent
            if let checked { empty[TaskItemAttribute.self] = checked }
            builder.append(empty)
        }
    }

    private static func inlineAttributedString(_ markup: Markup) -> AttributedString {
        switch markup {
        case let text as Text:
            return AttributedString(text.string)
        case let strong as Strong:
            var s = concatInline(strong.children)
            applyInline(.stronglyEmphasized, to: &s)
            return s
        case let em as Emphasis:
            var s = concatInline(em.children)
            applyInline(.emphasized, to: &s)
            return s
        case let code as InlineCode:
            var s = AttributedString(code.code)
            applyInline(.code, to: &s)
            return s
        case let link as Link:
            var s = concatInline(link.children)
            if let dest = link.destination, let url = URL(string: dest) {
                s.link = url
            }
            return s
        default:
            return AttributedString(markup.format())
        }
    }

    private static func concatInline(_ children: some Sequence<Markup>) -> AttributedString {
        var out = AttributedString()
        for child in children { out.append(inlineAttributedString(child)) }
        return out
    }

    private static func applyInline(_ intent: InlinePresentationIntent, to s: inout AttributedString) {
        for run in s.runs {
            let merged = (s[run.range].inlinePresentationIntent ?? []).union(intent)
            s[run.range].inlinePresentationIntent = merged
        }
    }

    // MARK: - Save: AttributedString -> Markdown

    public static func markdown(from attributed: AttributedString) -> String {
        var blocks: [(intent: PresentationIntent?, range: Range<AttributedString.Index>, checked: Bool?)] = []
        for run in attributed.runs {
            let intent = run.presentationIntent
            let checked = run[TaskItemAttribute.self]
            // Skip the structural block-separator newline runs the load path inserts
            // between blocks (no intent, content is only newlines): block separation
            // is reinstated by `joined(separator: "\n")` below.
            if intent == nil {
                let text = String(attributed[run.range].characters)
                if !text.isEmpty, text.allSatisfy({ $0 == "\n" }) { continue }
            }
            if let last = blocks.last, last.intent == intent {
                blocks[blocks.count - 1].range = last.range.lowerBound..<run.range.upperBound
                if blocks[blocks.count - 1].checked == nil { blocks[blocks.count - 1].checked = checked }
            } else {
                blocks.append((intent, run.range, checked))
            }
        }

        let lines = blocks.map { renderBlock(intent: $0.intent, range: $0.range, checked: $0.checked, in: attributed) }
        var text = lines.joined(separator: "\n")
        if !text.hasSuffix("\n") { text += "\n" }
        return text
    }

    private static func renderBlock(
        intent: PresentationIntent?,
        range: Range<AttributedString.Index>,
        checked: Bool?,
        in attributed: AttributedString
    ) -> String {
        let kinds = intent?.components.map(\.kind) ?? [.paragraph]

        if let lang = codeBlockLanguage(in: kinds) {
            let raw = String(attributed[range].characters)
            return "```\(lang ?? "")\n\(raw)\n```"
        }

        let inline = inlineMarkdown(for: range, in: attributed)

        if let level = headerLevel(in: kinds) {
            return String(repeating: "#", count: level) + " " + inline
        }
        if let ordinal = orderedOrdinal(in: kinds) {
            return "\(ordinal). \(inline)"
        }
        if isUnordered(kinds) {
            if let checked { return "- [\(checked ? "x" : " ")] \(inline)" }
            return "- \(inline)"
        }
        return inline
    }

    private static func headerLevel(in kinds: [PresentationIntent.Kind]) -> Int? {
        for k in kinds { if case .header(let l) = k { return l } }
        return nil
    }
    private static func orderedOrdinal(in kinds: [PresentationIntent.Kind]) -> Int? {
        var inOrdered = false, ordinal = 1
        for k in kinds {
            if case .orderedList = k { inOrdered = true }
            if case .listItem(let o) = k { ordinal = o }
        }
        return inOrdered ? ordinal : nil
    }
    private static func isUnordered(_ kinds: [PresentationIntent.Kind]) -> Bool {
        kinds.contains { if case .unorderedList = $0 { return true } else { return false } }
    }
    private static func codeBlockLanguage(in kinds: [PresentationIntent.Kind]) -> String?? {
        for k in kinds { if case .codeBlock(let hint) = k { return .some(hint) } }
        return .none
    }

    private static func inlineMarkdown(for range: Range<AttributedString.Index>, in attributed: AttributedString) -> String {
        var out = ""
        for run in attributed[range].runs {
            let text = String(attributed[run.range].characters)
            let intent = run.inlinePresentationIntent ?? []
            var piece: String
            if intent.contains(.code) {
                piece = "`\(text)`"
            } else {
                piece = escapeInline(text)
                if intent.contains(.stronglyEmphasized) { piece = "**\(piece)**" }
                if intent.contains(.emphasized) { piece = "*\(piece)*" }
            }
            if let url = run.link { piece = "[\(piece)](\(url.absoluteString))" }
            out += piece
        }
        return out
    }

    private static func escapeInline(_ text: String) -> String {
        var result = ""
        for ch in text {
            if "\\`*_[]".contains(ch) { result.append("\\") }
            result.append(ch)
        }
        return result
    }
}
