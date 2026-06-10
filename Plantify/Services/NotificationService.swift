import Foundation
import UserNotifications

/// Gentle, strictly opt-in reminders: at most ONE notification per day,
/// scheduled locally, removed entirely the moment the player opts out.
final class NotificationService {

    private static let reminderID = "plantify.daily.reminder"

    /// Requests permission (if needed) and schedules the single daily
    /// reminder. Returns whether reminders are actually active.
    @discardableResult
    func enableDailyReminder() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Plantify"
        content.body = "Your greenhouse has room for one more seed."
        content.sound = .default

        var components = DateComponents()
        components.hour = 18
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.reminderID,
                                            content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        try? await center.add(request)
        return true
    }

    func disableDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
    }
}
