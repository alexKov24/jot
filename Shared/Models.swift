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

    var openItems: [ChecklistItem] { items.filter { !$0.done } }
}
