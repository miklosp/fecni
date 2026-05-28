import Foundation

public enum VaultLocator {

    private struct Config: Decodable {
        struct Entry: Decodable {
            let path: String
            let ts: Double?
            let open: Bool?
        }
        let vaults: [String: Entry]?
    }

    /// Parse the contents of an Obsidian `obsidian.json` file into vaults,
    /// sorted most-recently-opened first.
    public static func vaults(fromObsidianConfig data: Data) throws -> [ObsidianVault] {
        let config = try JSONDecoder().decode(Config.self, from: data)
        let entries = config.vaults ?? [:]
        return entries.values
            .map { entry in
                ObsidianVault(
                    path: entry.path,
                    isOpen: entry.open ?? false,
                    lastOpened: entry.ts.map { Date(timeIntervalSince1970: $0 / 1000) }
                )
            }
            .sorted { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
    }

    /// Standard location of Obsidian's config on macOS.
    public static var defaultConfigURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("obsidian/obsidian.json")
    }

    /// Read and parse the config on disk; returns [] if the file is missing or unreadable.
    public static func detectedVaults(configURL: URL = defaultConfigURL) -> [ObsidianVault] {
        guard let data = try? Data(contentsOf: configURL) else { return [] }
        return (try? vaults(fromObsidianConfig: data)) ?? []
    }
}
