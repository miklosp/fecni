import ServiceManagement

/// The app's own "launch at login" registration, wrapping `SMAppService`.
///
/// The OS is the source of truth: `isEnabled` reads the live registration
/// status rather than a stored flag, so the Settings toggle can't drift from
/// System Settings ▸ General ▸ Login Items if the user changes it there.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
