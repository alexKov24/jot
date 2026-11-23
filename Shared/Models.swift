import Foundation

struct ChecklistItem: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var text: String
    var done = false
}

struct Idea: Codable, Identifiable, Hashable, Sendable {
    enum Status: String, Codable, Sendable { case expanding, ready, failed }

    var id = UUID()
    var note: String
    var title: String
    var items: [ChecklistItem] = []
    var status: Status = .expanding
    var error: String?
    var createdAt = Date()
    var remindAt: Date?
    /// The reminder is for the day of `remindAt`, with no time.
    var remindAllDay: Bool?
    /// Apple Reminders calendar item identifier.
    var reminderID: String?
    /// Set when the jot is deleted; it's purged for good 30 days later.
    var deletedAt: Date?

    var openItems: [ChecklistItem] { items.filter { !$0.done } }

    /// When the reminder time has passed: the end of the day for all-day reminders.
    var dueBy: Date? {
        guard let remindAt else { return nil }
        guard remindAllDay == true else { return remindAt }
        return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: remindAt))
    }

    /// Its time has passed, so it moves to the backlog.
    func isBacklog(at now: Date = .now) -> Bool { dueBy.map { $0 <= now } ?? false }
}
