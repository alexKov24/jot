import AppKit
import UserNotifications

/// Local notifications: one when a jot finishes expanding, one at its reminder time.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()
    /// Opens the ideas list when a notification is clicked.
    var onOpen: (() -> Void)?

    func start() {
        center.delegate = self
        Task { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
    }

    /// The jot finished expanding (or failed).
    func expanded(_ idea: Idea) {
        let content = UNMutableNotificationContent()
        if idea.status == .failed {
            content.title = "Couldn't expand jot"
            content.body = idea.note
        } else {
            content.title = idea.title
            content.body = idea.items.map { "• \($0.text)" }.joined(separator: "\n")
        }
        center.add(UNNotificationRequest(identifier: "ready-\(idea.id)", content: content, trigger: nil))
    }

    /// Schedules the jot's reminder; all-day reminders fire at 9:00. Replaces any earlier one.
    func schedule(_ idea: Idea) {
        guard var date = idea.remindAt else { return cancel(idea.id) }
        if idea.remindAllDay == true {
            date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        }
        guard date > .now else { return cancel(idea.id) }
        let content = UNMutableNotificationContent()
        content.title = idea.title
        content.body = idea.openItems.map { "• \($0.text)" }.joined(separator: "\n")
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: "remind-\(idea.id)", content: content, trigger: trigger))
    }

    func cancel(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["remind-\(id)"])
    }

    // Show banners even while a Jot panel is in front.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { onOpen?() }
    }
}
