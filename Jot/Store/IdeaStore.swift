import AppKit
import Observation
import WidgetKit
import notify

@MainActor @Observable
final class IdeaStore {
    private(set) var ideas: [Idea] = []
    private(set) var folder: URL?
    private(set) var lastError: String?

    @ObservationIgnored private var notifyToken: Int32 = 0
    /// Set when jot.json exists but can't be parsed, so we never overwrite it.
    @ObservationIgnored private var loadFailed = false

    private var fileURL: URL { (folder ?? FolderAccess.fallback).appending(path: "jot.json") }

    func start() {
        folder = FolderAccess.resolve()
        load()
        notify_register_dispatch(AppGroup.toggledNotification, &notifyToken, .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyWidgetToggles() }
        }
        applyWidgetToggles()
        // Finish anything interrupted by a quit mid-expansion.
        for idea in ideas where idea.status == .expanding { expand(idea.id) }
    }

    // MARK: Actions

    func add(_ note: String) {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        let idea = Idea(note: note, title: note)
        ideas.insert(idea, at: 0)
        save()
        expand(idea.id)
    }

    func retry(_ id: UUID) {
        update(id) { $0.status = .expanding; $0.error = nil }
        expand(id)
    }

    func toggle(_ itemID: UUID) {
        for i in ideas.indices {
            if let j = ideas[i].items.firstIndex(where: { $0.id == itemID }) {
                ideas[i].items[j].done.toggle()
            }
        }
        save()
    }

    func delete(_ id: UUID) {
        ideas.removeAll { $0.id == id }
        save()
    }

    /// Switch to a new folder. An existing jot.json there wins; otherwise current ideas move in.
    func chooseFolder() {
        guard let url = FolderAccess.pick() else { return }
        do {
            try FolderAccess.save(url)
            folder?.stopAccessingSecurityScopedResource()
            folder = FolderAccess.resolve()
            if FileManager.default.fileExists(atPath: fileURL.path) { load() } else { save() }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func revealFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    var folderPath: String { (folder ?? FolderAccess.fallback).path(percentEncoded: false) }

    // MARK: AI

    private func expand(_ id: UUID) {
        guard let note = ideas.first(where: { $0.id == id })?.note else { return }
        let request = AppSettings.shared.request()
        Task {
            do {
                let result = try await AI.expand(note, with: request)
                update(id) {
                    $0.title = result.title
                    $0.items = result.items.map { ChecklistItem(text: $0) }
                    $0.status = .ready
                }
            } catch {
                update(id) {
                    $0.status = .failed
                    $0.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: Persistence

    private func update(_ id: UUID, _ change: (inout Idea) -> Void) {
        guard let i = ideas.firstIndex(where: { $0.id == id }) else { return }
        change(&ideas[i])
        save()
    }

    private func applyWidgetToggles() {
        let ids = AppGroup.takeToggles()
        guard !ids.isEmpty else { return }
        ids.forEach(toggle)
    }

    private func load() {
        loadFailed = false
        guard let data = try? Data(contentsOf: fileURL) else { ideas = []; return }
        do {
            ideas = try JSONDecoder.jot.decode([Idea].self, from: data)
            lastError = nil
        } catch {
            loadFailed = true
            lastError = "Couldn't read \(fileURL.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func save() {
        guard !loadFailed else { return }
        do {
            try JSONEncoder.jot.encode(ideas).write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
        }
        AppGroup.writeSnapshot(ideas)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
