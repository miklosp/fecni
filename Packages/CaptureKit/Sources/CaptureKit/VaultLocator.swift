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
            .sorted { lhs, rhs in
                let l = lhs.lastOpened ?? .distantPast
                let r = rhs.lastOpened ?? .distantPast
                // Tiebreak on path so equal timestamps don't reorder across launches.
                return l == r ? lhs.path < rhs.path : l > r
            }
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

    /// Immediate child directories of a vault, excluding dot-folders, sorted by name.
    public static func subfolders(ofVault vaultPath: String) -> [String] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: vaultPath, isDirectory: true)
        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .map { $0.lastPathComponent }
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    /// A folder is an Obsidian vault if it contains a `.obsidian` directory.
    public static func isVault(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let dot = URL(fileURLWithPath: path).appendingPathComponent(".obsidian").path
        return FileManager.default.fileExists(atPath: dot, isDirectory: &isDir) && isDir.boolValue
    }
}
