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
