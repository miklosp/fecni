import SwiftUI

/// A Liquid Glass pill in the editor's bottom-right corner. Collapsed, it's a
/// small glass circle showing the `keyboard` glyph. Expanding grows the glass
/// capsule leftward, unmasking the keyboard-shortcut hints right-to-left — the
/// hints stay put; the widening glass simply reveals more of them.
///
/// The toggle glyph is a *separate overlay* pinned to the trailing edge, not
/// part of the clipped, growing track, so it can never move with the reveal —
/// it only morphs `keyboard` ⟷ ✕ in place via the native symbol-replace
/// transition.
struct ShortcutsHint: View {
    private let items: [(keys: String, label: String)] = [
        ("⌘1/2/3", "Heading"),
        ("⌘B", "Bold"),
        ("⌘I", "Italic"),
    ]

    private let buttonWidth: CGFloat = 26
    private let trailingPadding: CGFloat = 12
    /// Collapsed pill width: the toggle glyph centered, i.e. its frame plus
    /// equal padding on both sides.
    private var collapsedWidth: CGFloat { buttonWidth + trailingPadding * 2 }

    @State private var isExpanded = false
    @State private var expandedWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var width: CGFloat {
        isExpanded ? max(expandedWidth, collapsedWidth) : collapsedWidth
    }

    var body: some View {
        GlassEffectContainer {
            glassTrack
        }
        .overlay(alignment: .trailing) { toggleGlyph }
        .contentShape(.capsule)
        .onTapGesture {
            guard !isExpanded else { return }
            toggle()
        }
        .help("Keyboard shortcuts")
    }

    /// The growing, clipped glass capsule holding the chips. A trailing spacer
    /// the width of the toggle glyph reserves room so the chips never slide
    /// under the pinned glyph overlay. The content is clipped to the capsule
    /// *before* `.glassEffect`, so the material (applied last, outermost) is
    /// never clipped away.
    private var glassTrack: some View {
        HStack(spacing: 16) {
            ForEach(items, id: \.keys) { item in
                HStack(spacing: 6) {
                    Text(item.keys).font(.caption.monospaced())
                    Text(item.label).font(.caption).foregroundStyle(.secondary)
                }
            }
            Color.clear.frame(width: buttonWidth, height: 24)
        }
        .padding(.leading, 16)
        .padding(.trailing, trailingPadding)
        .padding(.vertical, 10)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { expandedWidth = $0 }
        .frame(width: width, alignment: .trailing)
        .clipShape(.capsule)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    /// Pinned to the trailing edge regardless of the capsule's width, so it
    /// stays put and only the glyph morphs in place.
    private var toggleGlyph: some View {
        Button(action: toggle) {
            Image(systemName: isExpanded ? "xmark.circle.fill" : "keyboard")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.secondary)
                .frame(width: buttonWidth, height: 24)
        }
        .buttonStyle(.plain)
        .padding(.trailing, trailingPadding)
    }

    private func toggle() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        }
    }
}
