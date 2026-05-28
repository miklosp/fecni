import Foundation

public struct ObsidianVault: Equatable, Sendable {
    public let path: String
    public let isOpen: Bool
    public let lastOpened: Date?

    public var name: String { URL(fileURLWithPath: path).lastPathComponent }

    public init(path: String, isOpen: Bool, lastOpened: Date?) {
        self.path = path
        self.isOpen = isOpen
        self.lastOpened = lastOpened
    }
}
