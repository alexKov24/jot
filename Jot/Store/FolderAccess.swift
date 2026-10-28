import AppKit

/// The user-chosen data folder, kept across launches with a security-scoped bookmark.
enum FolderAccess {
    private static let key = "folderBookmark"

    /// Used until the user picks a folder: the app's own sandbox container.
    static var fallback: URL {
        let url = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor
    static func pick() -> URL? {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for Jot"
        panel.message = "Jot saves your ideas as jot.json in this folder."
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL.documentsDirectory
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func save(_ url: URL) throws {
        let data = try url.bookmarkData(options: .withSecurityScope)
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Resolves the bookmark and starts access for the life of the app.
    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource()
        else { return nil }
        if stale { try? save(url) }
        return url
    }
}
