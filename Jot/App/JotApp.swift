@preconcurrency import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let capture = Self("capture", initial: .init(.j, modifiers: [.control, .option]))
    static let list = Self("list", initial: .init(.l, modifiers: [.control, .option]))
}

@main
struct JotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var app

    var body: some Scene {
        MenuBarExtra("Jot", image: "MenuBarIcon") {
            MenuContent(app: app)
        }
        Settings {
            SettingsView()
                .environment(app.store)
                .environment(AppSettings.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = IdeaStore()
    private lazy var capture = PanelController(closesOnResign: true) { [unowned self] close in
        CaptureView { note in
            self.store.add(note)
            close()
        }
        .environment(AppSettings.shared)
    }
    private lazy var list = PanelController(closesOnResign: false, autosave: "IdeasPanel") { [unowned self] _ in
        IdeasView().environment(self.store)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        Updates.shared.start()
        KeyboardShortcuts.onKeyUp(for: .capture) { [unowned self] in capture.toggle() }
        KeyboardShortcuts.onKeyUp(for: .list) { [unowned self] in list.toggle() }
        if store.folder == nil, !UserDefaults.standard.bool(forKey: "askedForFolder") {
            UserDefaults.standard.set(true, forKey: "askedForFolder")
            store.chooseFolder()
        }
    }

    /// "Copy to Jot" service: saves the selected text as a new idea.
    @objc func copyToJot(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else { return }
        store.add(text)
    }

    func showCapture() { capture.show() }
    func showList() { list.show() }
}

struct MenuContent: View {
    let app: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if let release = Updates.shared.available {
            Button("Update Available (v\(release.version))…") { NSWorkspace.shared.open(release.url) }
            Divider()
        }
        Button("New Idea") { app.showCapture() }
        Button("Show Ideas") { app.showList() }
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Check for Updates…") { Task { await Updates.shared.checkNow() } }
        Divider()
        Button("Quit Jot") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
