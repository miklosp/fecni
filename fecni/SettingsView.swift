import SwiftUI
import KeyboardShortcuts
import CaptureKit

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var showLoginItemError = false
    @State private var loginItemErrorMessage = ""

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open fecni at login", isOn: launchAtLoginBinding)
            }

            Section("Save notes to") {
                Button("Choose Folder…", action: chooseFolder)
                if let path = coordinator.settings.folderPath {
                    Text(path).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No folder chosen yet.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Open capture:", name: .openCapture)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .alert("Couldn’t update login item", isPresented: $showLoginItemError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemErrorMessage)
        }
    }

    /// Mirrors the live `SMAppService` status. A failed register/unregister
    /// leaves the OS state unchanged and surfaces an alert; reading the status
    /// back on the next render snaps the toggle to where it actually is.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LoginItem.isEnabled },
            set: { enabled in
                do {
                    try LoginItem.setEnabled(enabled)
                } catch {
                    loginItemErrorMessage = error.localizedDescription
                    showLoginItemError = true
                }
            }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            coordinator.updateSettings(CaptureSettings(folderPath: url.path))
        }
    }
}
