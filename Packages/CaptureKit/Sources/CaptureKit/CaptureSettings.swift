import Foundation

public struct CaptureSettings: Equatable, Codable, Sendable {
    public var folderPath: String?

    public init(folderPath: String? = nil) {
        self.folderPath = folderPath
    }

    /// The folder notes are saved into, or nil if none has been chosen.
    public var resolvedDirectory: URL? {
        folderPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
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
