import Foundation
import UserNotifications

enum NotificationScheduler {
    static let requestID = "moodsync.daily-checkin"

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func schedule(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = "Time to check in"
        content.body = "Share a mood with your circle. One tap is enough."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
    }
}
