import Testing
import Foundation
@testable import CaptureKit

@Test func defaultsAreEmpty() {
    let s = CaptureSettings()
    #expect(s.vaultPath == nil)
    #expect(s.subfolder == "")
}

@Test func storeRoundTripsThroughUserDefaults() {
    let defaults = UserDefaults(suiteName: "fecni.test.\(UUID().uuidString)")!
    let store = SettingsStore(defaults: defaults)
    #expect(store.load() == CaptureSettings())

    let updated = CaptureSettings(vaultPath: "/Users/me/Vault", subfolder: "00-Inbox")
    store.save(updated)
    #expect(store.load() == updated)
}

@Test func resolvedDirectoryJoinsVaultAndSubfolder() {
    let s = CaptureSettings(vaultPath: "/Users/me/Vault", subfolder: "00-Inbox")
    #expect(s.resolvedDirectory?.path == "/Users/me/Vault/00-Inbox")

    let root = CaptureSettings(vaultPath: "/Users/me/Vault", subfolder: "")
    #expect(root.resolvedDirectory?.path == "/Users/me/Vault")

    #expect(CaptureSettings(vaultPath: nil).resolvedDirectory == nil)
}
