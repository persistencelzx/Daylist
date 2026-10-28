import Foundation
import UserNotifications

actor ReminderScheduler {
    static let shared = ReminderScheduler()
    private var syncing = false
    private var needsAnotherPass = false

    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    // Actor reentrancy is coalesced: after any concurrent edit, the last pass reads fresh disk data.
    func sync() async throws {
        needsAnotherPass = true
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        repeat {
            needsAnotherPass = false
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }
            let state = try ChecklistStore.shared().read()
            let plan = ReminderPlan.build(state: state)
            let desired = Set(plan.map(\.identifier))
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter {
                $0.hasPrefix("daylist.") && !desired.contains($0)
            })
            let delivered = await center.deliveredNotifications()
            let completed = delivered.compactMap { notification -> String? in
                let info = notification.request.content.userInfo
                guard let id = info["itemID"] as? String, let day = info["day"] as? String else { return nil }
                let item = state.items.first { $0.id.uuidString == id }
                return item == nil || item!.paused || item!.completedDays.contains(day)
                    ? notification.request.identifier : nil
            }
            center.removeDeliveredNotifications(withIdentifiers: completed)
            for reminder in plan {
                try Task.checkCancellation()
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = "留一点时间，完成今天的小事。"
                content.sound = .default
                content.userInfo = ["itemID": reminder.itemID.uuidString, "day": reminder.dayKey]
                var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                components.calendar = Calendar.current
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
            }
        } while needsAnotherPass
    }
}
