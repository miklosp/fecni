import Testing
import Foundation
@testable import CaptureKit

private func fixtureData() throws -> Data {
    let url = Bundle.module.url(forResource: "obsidian", withExtension: "json")!
    return try Data(contentsOf: url)
}

@Test func parsesVaultsSortedByMostRecentlyOpened() throws {
    let vaults = try VaultLocator.vaults(fromObsidianConfig: fixtureData())
    #expect(vaults.count == 2)
    #expect(vaults[0].path == "/Users/me/Notes")   // newer ts first
    #expect(vaults[0].isOpen == true)
    #expect(vaults[0].name == "Notes")
    #expect(vaults[1].path == "/Users/me/Archive")
    #expect(vaults[1].isOpen == false)
}

@Test func equalTimestampsSortDeterministicallyByPath() throws {
    let json = #"""
    {"vaults":{
      "z":{"path":"/Users/me/Zeta","ts":1000,"open":false},
      "a":{"path":"/Users/me/Alpha","ts":1000,"open":false}
    }}
    """#
    let vaults = try VaultLocator.vaults(fromObsidianConfig: Data(json.utf8))
    // Same ts → ordered by path, regardless of JSON-dictionary enumeration order.
    #expect(vaults.map(\.path) == ["/Users/me/Alpha", "/Users/me/Zeta"])
}

@Test func emptyOrMissingVaultsKeyYieldsEmptyList() throws {
    #expect(try VaultLocator.vaults(fromObsidianConfig: Data("{}".utf8)).isEmpty)
    #expect(try VaultLocator.vaults(fromObsidianConfig: Data(#"{"vaults":{}}"#.utf8)).isEmpty)
}

@Test func malformedJSONThrows() {
    #expect(throws: (any Error).self) {
        _ = try VaultLocator.vaults(fromObsidianConfig: Data("not json".utf8))
    }
}

@Test func listsImmediateSubfoldersExcludingDotFolders() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: root.appendingPathComponent("00-Inbox"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("Projects"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent(".obsidian"), withIntermediateDirectories: true)
    try Data().write(to: root.appendingPathComponent("note.md"))
    defer { try? fm.removeItem(at: root) }

    let subs = VaultLocator.subfolders(ofVault: root.path)
    #expect(subs == ["00-Inbox", "Projects"])   // sorted, no .obsidian, no files
}

@Test func isVaultTrueWhenDotObsidianPresent() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: root.appendingPathComponent(".obsidian"), withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    #expect(VaultLocator.isVault(root.path) == true)
    #expect(VaultLocator.isVault(fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).path) == false)
}
