import Foundation

public struct CaptureStore: @unchecked Sendable {
    private let directory: URL
    private let formatter: DateFormatter

    public init(directory: URL, timeZone: TimeZone = .current) {
        self.directory = directory
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd HHmm"
        self.formatter = f
    }

    /// Writes markdown to a new collision-safe file in `directory`. Returns the URL,
    /// or nil if the trimmed content is empty (no file is created).
    @discardableResult
    public func write(markdown: String, at date: Date) throws -> URL? {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = Set((try? fm.contentsOfDirectory(atPath: directory.path)) ?? [])
        let url = directory.appendingPathComponent(filename(at: date, existing: existing))
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// "yyyy-MM-dd HHmm.md", with " 2", " 3"… inserted before the extension on collision.
    public func filename(at date: Date, existing: Set<String>) -> String {
        let base = formatter.string(from: date)
        if !existing.contains("\(base).md") { return "\(base).md" }
        var n = 2
        while existing.contains("\(base) \(n).md") { n += 1 }
        return "\(base) \(n).md"
    }
}
