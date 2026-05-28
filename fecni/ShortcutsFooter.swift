import SwiftUI

/// The collapsible footer listing the editor's keyboard shortcuts.
struct ShortcutsFooter: View {
    private let items: [(keys: String, label: String)] = [
        ("⌘B", "Bold"),
        ("⌘I", "Italic"),
        ("⌘1/2/3", "Heading"),
        ("⌘E", "Code block"),
        ("⌘L", "Task list"),
        ("⇧⌘U", "Bullet list"),
        ("⇧⌘O", "Numbered list"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(items, id: \.keys) { item in
                    HStack(spacing: 6) {
                        Text(item.keys).font(.caption.monospaced())
                        Text(item.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(.quaternary)
    }
}
