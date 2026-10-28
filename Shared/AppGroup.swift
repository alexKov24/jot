import Foundation
import notify

/// Shared container between the app and the widget.
/// The app owns the data; the widget reads `snapshot.json` and queues ticks in `toggles.json`.
enum AppGroup {
    static let id = "FKB54TC53B.com.alexkovalev.jot"
    static let toggledNotification = "com.alexkovalev.jot.toggled"

    private static var container: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)!
    }
    private static var snapshotURL: URL { container.appending(path: "snapshot.json") }
    private static var inboxURL: URL { container.appending(path: "toggles.json") }

    static func readSnapshot() -> [Idea] {
        read([Idea].self, from: snapshotURL) ?? []
    }

    static func writeSnapshot(_ ideas: [Idea]) {
        write(ideas, to: snapshotURL)
    }

    /// Called by the widget: flip the item in the snapshot so the widget updates at once,
    /// queue the change for the app, and wake the app up.
    static func toggle(_ itemID: UUID) {
        var ideas = readSnapshot()
        for i in ideas.indices {
            if let j = ideas[i].items.firstIndex(where: { $0.id == itemID }) {
                ideas[i].items[j].done.toggle()
            }
        }
        writeSnapshot(ideas)
        coordinate(inboxURL) { url in
            let queued = read([UUID].self, from: url) ?? []
            write(queued + [itemID], to: url)
        }
        notify_post(toggledNotification)
    }

    /// Called by the app: take all queued widget ticks.
    static func takeToggles() -> [UUID] {
        var ids: [UUID] = []
        coordinate(inboxURL) { url in
            ids = read([UUID].self, from: url) ?? []
            if !ids.isEmpty { try? FileManager.default.removeItem(at: url) }
        }
        return ids
    }

    private static func coordinate(_ url: URL, _ body: (URL) -> Void) {
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &error, byAccessor: body)
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.jot.decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder.jot.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

extension JSONEncoder {
    static var jot: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var jot: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
