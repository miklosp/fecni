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

@Test func emptyOrMissingVaultsKeyYieldsEmptyList() throws {
    #expect(try VaultLocator.vaults(fromObsidianConfig: Data("{}".utf8)).isEmpty)
    #expect(try VaultLocator.vaults(fromObsidianConfig: Data(#"{"vaults":{}}"#.utf8)).isEmpty)
}

@Test func malformedJSONThrows() {
    #expect(throws: (any Error).self) {
        _ = try VaultLocator.vaults(fromObsidianConfig: Data("not json".utf8))
    }
}
