import EventKit

/// Puts timed ideas into Apple Reminders, which alerts here and syncs to iPhone.
@MainActor
enum Reminders {
    private static let store = EKEventStore()

    enum Failure: LocalizedError {
        case denied, noList

        var errorDescription: String? {
            switch self {
            case .denied: "Allow Jot to use Reminders in System Settings → Privacy & Security → Reminders."
            case .noList: "Reminders has no default list."
            }
        }
    }

    static var status: EKAuthorizationStatus { EKEventStore.authorizationStatus(for: .reminder) }

    /// Shows the system prompt the first time; afterwards only System Settings can change it.
    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!

    /// Removes the reminder; a reminder already deleted in the Reminders app is fine.
    static func delete(_ id: String) throws {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        try store.remove(reminder, commit: true)
    }

    /// Creates the idea's reminder, or updates it if it already exists. Returns its identifier.
    static func save(_ idea: Idea, at date: Date) async throws -> String {
        guard try await store.requestFullAccessToReminders() else { throw Failure.denied }
        let reminder: EKReminder
        if let id = idea.reminderID, let existing = store.calendarItem(withIdentifier: id) as? EKReminder {
            reminder = existing
        } else {
            guard let list = store.defaultCalendarForNewReminders() else { throw Failure.noList }
            reminder = EKReminder(eventStore: store)
            reminder.calendar = list
        }
        reminder.title = idea.title
        reminder.notes = idea.items.map { "• \($0.text)" }.joined(separator: "\n")
        if idea.remindAllDay == true {
            // Day only: shows as all-day; Reminders alerts at its all-day notification time.
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
            reminder.alarms = nil
        } else {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            reminder.alarms = [EKAlarm(absoluteDate: date)]
        }
        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }
}
