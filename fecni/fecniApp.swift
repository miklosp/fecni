import SwiftUI
import AppKit
import CaptureKit

@main
struct fecniApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("fecni", systemImage: "square.and.pencil") {
            Button("New Note") { coordinator.openCapture() }
            Divider()
            SettingsLink { Text("Settings…") }
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

        Settings {
            SettingsView(coordinator: coordinator)
        }
    }
}
