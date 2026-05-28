import Testing
import Foundation
@testable import CaptureKit

private func date(_ iso: String) -> Date {
    let f = ISO8601DateFormatter()
    return f.date(from: iso)!
}

@Test func filenameUsesTimestampFormat() {
    let store = CaptureStore(directory: URL(fileURLWithPath: "/tmp"), timeZone: TimeZone(identifier: "UTC")!)
    let name = store.filename(at: date("2026-05-28T14:32:00Z"), existing: [])
    #expect(name == "2026-05-28 1432.md")
}

@Test func filenameAppendsSuffixOnCollision() {
    let store = CaptureStore(directory: URL(fileURLWithPath: "/tmp"), timeZone: TimeZone(identifier: "UTC")!)
    let d = date("2026-05-28T14:32:00Z")
    #expect(store.filename(at: d, existing: ["2026-05-28 1432.md"]) == "2026-05-28 1432 2.md")
    #expect(store.filename(at: d, existing: ["2026-05-28 1432.md", "2026-05-28 1432 2.md"]) == "2026-05-28 1432 3.md")
}

@Test func writeCreatesFileWithContent() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: dir) }
    let store = CaptureStore(directory: dir, timeZone: TimeZone(identifier: "UTC")!)

    let url = try store.write(markdown: "# Hello\n", at: date("2026-05-28T14:32:00Z"))
    #expect(url != nil)
    #expect(url?.lastPathComponent == "2026-05-28 1432.md")
    #expect(try String(contentsOf: url!, encoding: .utf8) == "# Hello\n")
}

@Test func writeSkipsEmptyOrWhitespaceContent() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: dir) }
    let store = CaptureStore(directory: dir, timeZone: TimeZone(identifier: "UTC")!)

    #expect(try store.write(markdown: "   \n\t", at: date("2026-05-28T14:32:00Z")) == nil)
    let contents = try? fm.contentsOfDirectory(atPath: dir.path)
    #expect(fm.fileExists(atPath: dir.path) == false || (contents ?? []).isEmpty)
}

@Test func writeCreatesIntermediateDirectories() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("nested")
    defer { try? fm.removeItem(at: dir.deletingLastPathComponent()) }
    let store = CaptureStore(directory: dir, timeZone: TimeZone(identifier: "UTC")!)

    let url = try store.write(markdown: "hi", at: date("2026-05-28T14:32:00Z"))
    #expect(url != nil)
    #expect(fm.fileExists(atPath: url!.path))
}
