import SwiftUI
import CaptureKit

/// Holds the in-progress note as an `AttributedString` and bridges dismissal to
/// a Markdown string for the coordinator to persist.
@MainActor
@Observable
final class CaptureModel {
    var text = AttributedString()
    var selection = AttributedTextSelection()
    var showFooter = false

    private let draftStore: DraftStore
    private let onDismiss: (String) -> Void

    init(draftStore: DraftStore, onDismiss: @escaping (String) -> Void) {
        self.draftStore = draftStore
        self.onDismiss = onDismiss
    }

    func textChanged() {
        draftStore.scheduleSave(MarkdownDocument.markdown(from: text))
    }

    func requestDismiss() {
        onDismiss(MarkdownDocument.markdown(from: text))
    }
}

struct CaptureView: View {
    @Bindable var model: CaptureModel

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $model.text, selection: $model.selection)
                .font(.body)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(24)
                .onChange(of: model.text) { _, _ in model.textChanged() }

            HStack {
                Spacer()
                Button {
                    model.showFooter.toggle()
                } label: {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Keyboard shortcuts")
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            if model.showFooter {
                ShortcutsFooter()
            }
        }
        .frame(minWidth: 460, minHeight: 280)
        .background(.regularMaterial)
        .onExitCommand { model.requestDismiss() }
        .modifier(EditorCommands(model: model))
    }
}
