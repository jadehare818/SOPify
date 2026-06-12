import Foundation
import UserNotifications
import SwiftData

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleTrigger(_ trigger: Trigger, sopName: String) {
        guard trigger.isEnabled else { return }
        guard trigger.triggerKind == .scheduled else { return }

        let content = UNMutableNotificationContent()
        content.title = "SOPify"
        content.body = "Time for: \(sopName)"
        content.sound = .default
        content.userInfo = ["sopId": trigger.sop?.id.uuidString ?? ""]

        let unTrigger: UNNotificationTrigger

        switch trigger.triggerRecurrence {
        case .once:
            if let date = trigger.scheduledDate {
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                unTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            } else {
                return
            }
        case .daily:
            var comps = DateComponents()
            comps.hour = trigger.hour ?? 9
            comps.minute = trigger.minute ?? 0
            unTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        case .weekly:
            var comps = DateComponents()
            comps.weekday = trigger.weekday ?? 2
            comps.hour = trigger.hour ?? 9
            comps.minute = trigger.minute ?? 0
            unTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        case .monthly:
            var comps = DateComponents()
            comps.day = trigger.dayOfMonth ?? 1
            comps.hour = trigger.hour ?? 9
            comps.minute = trigger.minute ?? 0
            unTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }

        let request = UNNotificationRequest(
            identifier: trigger.id.uuidString,
            content: content,
            trigger: unTrigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleChainedNotification(sopName: String, sopId: UUID, delay: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = "Continue with \(sopName)?"
        content.body = "Previous SOP completed. Tap to start."
        content.sound = .default
        content.userInfo = ["sopId": sopId.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "chain-\(sopId.uuidString)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelTrigger(_ trigger: Trigger) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [trigger.id.uuidString])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    var isPaused: Bool {
        get { UserDefaults.standard.bool(forKey: "notifications_paused") }
        set { UserDefaults.standard.set(newValue, forKey: "notifications_paused") }
    }
}
