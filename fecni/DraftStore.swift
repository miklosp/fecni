import Foundation

/// Crash-recovery autosave: persists the in-progress note to a hidden file in
/// Application Support, debounced while typing, and cleared on a successful save.
@MainActor
final class DraftStore {
    private let url: URL
    private var pending: DispatchWorkItem?
    /// Serial queue for all draft disk I/O. Keeping writes and the clear/remove
    /// on one FIFO queue preserves ordering, so a debounced write enqueued
    /// before a `clear()` can't re-create the file afterwards.
    private let io = DispatchQueue(label: "work.miklos.fecni.draft-io")

    init(fileName: String = "draft.md") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("work.miklos.fecni", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.url = base.appendingPathComponent(fileName)
    }

    func scheduleSave(_ markdown: String) {
        pending?.cancel()
        let target = url
        let io = self.io
        // Debounce on the main actor (so cancel() stays serialized with the
        // scheduling) but push the actual disk write to the background queue.
        let work = DispatchWorkItem {
            io.async { try? markdown.write(to: target, atomically: true, encoding: .utf8) }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func saveNow(_ markdown: String) {
        pending?.cancel()
        let target = url
        // Synchronous so the note is on disk before the caller proceeds
        // (used on app termination, where the process exits right after).
        io.sync { try? markdown.write(to: target, atomically: true, encoding: .utf8) }
    }

    func load() -> String? {
        guard let s = try? String(contentsOf: url, encoding: .utf8),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }

    func clear() {
        pending?.cancel()
        let target = url
        io.async { try? FileManager.default.removeItem(at: target) }
    }
}
