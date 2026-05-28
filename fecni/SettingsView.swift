import SwiftUI
import KeyboardShortcuts
import CaptureKit

struct SettingsView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var vaults: [ObsidianVault] = VaultLocator.detectedVaults()

    var body: some View {
        Form {
            Section("Vault") {
                Picker("Vault", selection: vaultBinding) {
                    Text("Choose…").tag(String?.none)
                    ForEach(vaults, id: \.path) { vault in
                        Text(vault.name).tag(Optional(vault.path))
                    }
                }
                Button("Choose Folder…", action: chooseFolderManually)

                if let path = coordinator.settings.vaultPath {
                    Picker("Subfolder", selection: subfolderBinding) {
                        Text("(vault root)").tag("")
                        ForEach(VaultLocator.subfolders(ofVault: path), id: \.self) { sub in
                            Text(sub).tag(sub)
                        }
                    }
                    Text(path).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Open capture:", name: .openCapture)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onAppear { vaults = VaultLocator.detectedVaults() }
    }

    private var vaultBinding: Binding<String?> {
        Binding(
            get: { coordinator.settings.vaultPath },
            set: { coordinator.updateSettings(CaptureSettings(vaultPath: $0, subfolder: "")) }
        )
    }

    private var subfolderBinding: Binding<String> {
        Binding(
            get: { coordinator.settings.subfolder },
            set: { coordinator.updateSettings(CaptureSettings(vaultPath: coordinator.settings.vaultPath, subfolder: $0)) }
        )
    }

    private func chooseFolderManually() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            coordinator.updateSettings(CaptureSettings(vaultPath: url.path, subfolder: ""))
        }
    }
}
