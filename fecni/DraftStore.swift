import Foundation

/// Crash-recovery autosave: persists the in-progress note to a hidden file in
/// Application Support, debounced while typing, and cleared on a successful save.
@MainActor
final class DraftStore {
    private let url: URL
    private var pending: DispatchWorkItem?

    init(fileName: String = "draft.md") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("work.miklos.fecni", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.url = base.appendingPathComponent(fileName)
    }

    func scheduleSave(_ markdown: String) {
        pending?.cancel()
        let target = url
        let work = DispatchWorkItem {
            try? markdown.write(to: target, atomically: true, encoding: .utf8)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func saveNow(_ markdown: String) {
        pending?.cancel()
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    func load() -> String? {
        guard let s = try? String(contentsOf: url, encoding: .utf8),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }

    func clear() {
        pending?.cancel()
        try? FileManager.default.removeItem(at: url)
    }
}
