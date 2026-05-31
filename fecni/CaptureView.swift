import SwiftUI
import MarkdownEngine

extension Notification.Name {
    /// Formatting requests posted to MarkdownEngine's editor bus (see
    /// `CaptureView.editorConfiguration`); fired by `CapturePanel`'s key
    /// equivalents. Only Bold/Italic/Heading are supported by the engine's
    /// public bus on 0.5.0.
    static let fecniApplyBold = Notification.Name("work.miklos.fecni.applyBold")
    static let fecniApplyItalic = Notification.Name("work.miklos.fecni.applyItalic")
    static let fecniApplyHeading = Notification.Name("work.miklos.fecni.applyHeading")
}

/// Holds the in-progress note as Markdown text. With MarkdownEngine the editor's
/// document *is* Markdown, so there is no AttributedString↔Markdown conversion —
/// the string is what gets saved.
@MainActor
@Observable
final class CaptureModel {
    var text: String = ""

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
        // The engine applies these when the matching notifications are posted;
        // CapturePanel posts them from the ⌘B / ⌘I / ⌘1–3 key equivalents.
        config.services.bus = MarkdownEditorBus(
            applyBoldRequest: .fecniApplyBold,
            applyItalicRequest: .fecniApplyItalic,
            applyHeadingRequest: .fecniApplyHeading
        )
        return config
    }

    private var editor: some View {
        NativeTextViewWrapper(text: $model.text, configuration: editorConfiguration)
            .onChange(of: model.text) { _, _ in model.textChanged() }
    }

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                // macOS 26+: the Liquid Glass pill floats in the corner.
                editor.overlay(alignment: .bottomTrailing) {
                    ShortcutsHint()
                        .padding(12)
                }
            } else {
                // macOS 14–25: a reserved footer strip below the editor so note
                // text can never scroll behind the hints.
                VStack(spacing: 0) {
                    editor
                    Divider()
                    ShortcutsFooter()
                }
            }
        }
        .frame(minWidth: 460, minHeight: 280)
        // The panel's full-size-content titlebar is transparent and empty;
        // without this SwiftUI insets content below the (invisible) titlebar,
        // making the top gap larger than the sides. Extend into it so the
        // editor's own 20pt text inset is the only top padding.
        .ignoresSafeArea(.container, edges: .top)
        .onExitCommand { model.requestDismiss() }
    }
}
