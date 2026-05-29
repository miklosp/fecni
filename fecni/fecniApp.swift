import SwiftUI
import AppKit
import CaptureKit

@main
struct fecniApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("fecni", systemImage: "square.and.pencil") {
            MenuContent(coordinator: coordinator)
        }

        Settings {
            SettingsView(coordinator: coordinator)
        }
    }
}

/// The menu-bar menu. Lives in a `View` (not the `App`) so it can use the
/// `openSettings` environment action.
private struct MenuContent: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("New Note") { coordinator.openCapture() }
        Divider()
        Button("Settings…") {
            // An accessory (menu-bar) app must activate before its Settings
            // window will come to the front instead of opening behind.
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        Button("Open Vault Folder") {
            if let dir = coordinator.settings.resolvedDirectory {
                NSWorkspace.shared.open(dir)
            }
        }
        .disabled(coordinator.settings.resolvedDirectory == nil)
        Divider()
        Button("Quit fecni") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
