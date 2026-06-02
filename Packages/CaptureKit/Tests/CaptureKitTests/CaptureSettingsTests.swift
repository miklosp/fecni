import Testing
import Foundation
@testable import CaptureKit

@Test func defaultsAreEmpty() {
    let s = CaptureSettings()
    #expect(s.folderPath == nil)
    #expect(s.resolvedDirectory == nil)
}

@Test func storeRoundTripsThroughUserDefaults() {
    let defaults = UserDefaults(suiteName: "fecni.test.\(UUID().uuidString)")!
    let store = SettingsStore(defaults: defaults)
    #expect(store.load() == CaptureSettings())

    let updated = CaptureSettings(folderPath: "/Users/me/Notes")
    store.save(updated)
    #expect(store.load() == updated)
}

@Test func resolvedDirectoryIsTheChosenFolder() {
    let s = CaptureSettings(folderPath: "/Users/me/Vault/00-Inbox")
    #expect(s.resolvedDirectory?.path == "/Users/me/Vault/00-Inbox")

    #expect(CaptureSettings(folderPath: nil).resolvedDirectory == nil)
}
