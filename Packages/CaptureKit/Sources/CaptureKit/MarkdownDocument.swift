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
}
