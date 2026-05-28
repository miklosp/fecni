import Foundation

public struct CaptureSettings: Equatable, Codable, Sendable {
    public var vaultPath: String?
    public var subfolder: String

    public init(vaultPath: String? = nil, subfolder: String = "") {
        self.vaultPath = vaultPath
        self.subfolder = subfolder
    }

    /// Vault root joined with the (possibly empty) subfolder, or nil if no vault chosen.
    public var resolvedDirectory: URL? {
        guard let vaultPath else { return nil }
        let base = URL(fileURLWithPath: vaultPath, isDirectory: true)
        return subfolder.isEmpty ? base : base.appendingPathComponent(subfolder, isDirectory: true)
    }
}

public struct SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "fecni.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> CaptureSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(CaptureSettings.self, from: data)
        else { return CaptureSettings() }
        return decoded
    }

    public func save(_ settings: CaptureSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
