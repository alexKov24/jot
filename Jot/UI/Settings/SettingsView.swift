import EventKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Models", systemImage: "sparkles") { ModelSettings() }
        }
        .frame(width: 560)
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    @Environment(IdeaStore.self) private var store
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var remindersStatus = Reminders.status

    var body: some View {
        Form {
            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("New idea", name: .capture)
                KeyboardShortcuts.Recorder("Show ideas", name: .list)
            }
            Section {
                LabeledContent("Folder") {
                    Text(store.folder == nil ? "Not chosen (app container)" : store.folderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Show in Finder") { store.revealFolder() }
                    Button("Choose…") { store.chooseFolder() }
                }
                if let error = store.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Ideas are saved as jot.json. Jot only has access to the folder you choose.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Reminders") {
                    switch remindersStatus {
                    case .fullAccess:
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .notDetermined:
                        Button("Allow…") {
                            Task {
                                _ = await Reminders.requestAccess()
                                remindersStatus = Reminders.status
                            }
                        }
                    default:
                        Button("Open System Settings…") { NSWorkspace.shared.open(Reminders.settingsURL) }
                    }
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Jot adds a reminder when a note asks for one, like \"remind me at 16:00\". Reminders syncs it to your iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                remindersStatus = Reminders.status
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
