import AppKit
import Observation
import WidgetKit
import notify

@MainActor @Observable
final class IdeaStore {
    /// Every jot, including deleted ones still in the 30-day window.
    private(set) var all: [Idea] = []
    private(set) var folder: URL?
    private(set) var lastError: String?

    var ideas: [Idea] { all.filter { $0.deletedAt == nil } }
    var deleted: [Idea] { all.filter { $0.deletedAt != nil } }

    static let keepDeleted: TimeInterval = 30 * 24 * 3600

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
        // Jot can run for weeks; purge expired jots daily, not only on launch.
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(24 * 3600))
                self?.purge()
            }
        }
    }

    // MARK: Actions

    func add(_ note: String) {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        let idea = Idea(note: note, title: note)
        all.insert(idea, at: 0)
        save()
        expand(idea.id)
    }

    func retry(_ id: UUID) {
        update(id) { $0.status = .expanding; $0.error = nil }
        expand(id)
    }

    /// Ticking the last open step moves the jot to Recently Deleted (its reminder stays).
    func toggle(_ itemID: UUID) {
        for i in all.indices {
            if let j = all[i].items.firstIndex(where: { $0.id == itemID }) {
                all[i].items[j].done.toggle()
                if all[i].items[j].done, all[i].openItems.isEmpty { all[i].deletedAt = .now }
            }
        }
        save()
    }

    /// Puts `id` where `target` is now.
    func move(_ id: UUID, to target: UUID) {
        guard id != target,
              let from = all.firstIndex(where: { $0.id == id }),
              let to = all.firstIndex(where: { $0.id == target })
        else { return }
        all.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        save()
    }

    /// Moves the jot to Recently Deleted.
    func delete(_ id: UUID, reminder: Bool = false) {
        if reminder, let reminderID = all.first(where: { $0.id == id })?.reminderID {
            do { try Reminders.delete(reminderID) } catch { lastError = error.localizedDescription }
        }
        update(id) { $0.deletedAt = .now }
    }

    func restore(_ id: UUID) {
        update(id) { $0.deletedAt = nil }
    }

    /// Removes the jot for good.
    func deleteNow(_ id: UUID) {
        all.removeAll { $0.id == id }
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
        guard let note = all.first(where: { $0.id == id })?.note else { return }
        let request = AppSettings.shared.request()
        Task {
            do {
                let result = try await AI.expand(note, with: request)
                update(id) {
                    $0.title = result.title
                    $0.items = result.items.map { ChecklistItem(text: $0) }
                    let remind = AI.remindDate(result.remindAt)
                    $0.remindAt = remind?.date
                    $0.remindAllDay = remind?.allDay
                    $0.status = .ready
                }
            } catch {
                update(id) {
                    $0.status = .failed
                    $0.error = error.localizedDescription
                }
                return
            }
            // The checklist is fine even if Reminders fails; show the error with Retry.
            guard let idea = all.first(where: { $0.id == id }), let date = idea.remindAt else { return }
            do {
                let reminderID = try await Reminders.save(idea, at: date)
                update(id) { $0.reminderID = reminderID }
            } catch {
                update(id) { $0.error = error.localizedDescription }
            }
        }
    }

    // MARK: Persistence

    private func update(_ id: UUID, _ change: (inout Idea) -> Void) {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        change(&all[i])
        save()
    }

    private func applyWidgetToggles() {
        let ids = AppGroup.takeToggles()
        guard !ids.isEmpty else { return }
        ids.forEach(toggle)
    }

    private func load() {
        loadFailed = false
        guard let data = try? Data(contentsOf: fileURL) else { all = []; return }
        do {
            all = try JSONDecoder.jot.decode([Idea].self, from: data)
            lastError = nil
            purge()
        } catch {
            loadFailed = true
            lastError = "Couldn't read \(fileURL.lastPathComponent): \(error.localizedDescription)"
        }
    }

    /// Deleted more than 30 days ago: gone for good.
    private func purge() {
        let cutoff = Date.now.addingTimeInterval(-Self.keepDeleted)
        let count = all.count
        all.removeAll { ($0.deletedAt ?? .now) <= cutoff }
        if all.count < count { save() }
    }

    private func save() {
        guard !loadFailed else { return }
        do {
            try JSONEncoder.jot.encode(all).write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
        }
        AppGroup.writeSnapshot(ideas)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
