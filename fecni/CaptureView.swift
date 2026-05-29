import SwiftUI
import MarkdownEngine

/// Holds the in-progress note as Markdown text. With MarkdownEngine the editor's
/// document *is* Markdown, so there is no AttributedString↔Markdown conversion —
/// the string is what gets saved.
@MainActor
@Observable
final class CaptureModel {
    var text: String = ""
    var showFooter = false

    private let draftStore: DraftStore
    private let onDismiss: (String) -> Void

    init(draftStore: DraftStore, onDismiss: @escaping (String) -> Void) {
        self.draftStore = draftStore
        self.onDismiss = onDismiss
    }

    func textChanged() {
        draftStore.scheduleSave(text)
    }

    func requestDismiss() {
        onDismiss(text)
    }
}

struct CaptureView: View {
    @Bindable var model: CaptureModel

    private var editorConfiguration: MarkdownEditorConfiguration {
        var config = MarkdownEditorConfiguration.default
        config.textInsets = TextInsets(horizontal: 20, vertical: 20)
        return config
    }

    var body: some View {
        VStack(spacing: 0) {
            NativeTextViewWrapper(text: $model.text, configuration: editorConfiguration)
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
        .onExitCommand { model.requestDismiss() }
    }
}
