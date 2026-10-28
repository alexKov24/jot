@preconcurrency import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let capture = Self("capture", default: .init(.j, modifiers: [.control, .option]))
    static let list = Self("list", default: .init(.l, modifiers: [.control, .option]))
}

@main
struct JotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var app

    var body: some Scene {
        MenuBarExtra("Jot", systemImage: "lightbulb.max") {
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
    private lazy var capture = PanelController(size: NSSize(width: 580, height: 96), closesOnResign: true) { [unowned self] close in
        CaptureView { note in
            self.store.add(note)
            close()
        }
        .environment(AppSettings.shared)
    }
    private lazy var list = PanelController(size: NSSize(width: 440, height: 600), closesOnResign: false) { [unowned self] _ in
        IdeasView().environment(self.store)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        KeyboardShortcuts.onKeyUp(for: .capture) { [unowned self] in capture.toggle() }
        KeyboardShortcuts.onKeyUp(for: .list) { [unowned self] in list.toggle() }
        if store.folder == nil, !UserDefaults.standard.bool(forKey: "askedForFolder") {
            UserDefaults.standard.set(true, forKey: "askedForFolder")
            store.chooseFolder()
        }
    }

    func showCapture() { capture.show() }
    func showList() { list.show() }
}

struct MenuContent: View {
    let app: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("New Idea") { app.showCapture() }
        Button("Show Ideas") { app.showList() }
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Jot") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
