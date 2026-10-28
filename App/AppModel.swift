import SwiftUI
import WidgetKit
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var state = ChecklistState()
    @Published var now = Date()
    @Published var error: String?
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingCount = 0
    @Published var lastReminderDate: Date?

    var today: [ChecklistItem] { state.today(now) }
    var pending: [ChecklistItem] { today.filter { !$0.isComplete(on: now) } }
    var completed: [ChecklistItem] { today.filter { $0.isComplete(on: now) } }
    var hasReminders: Bool { state.items.contains { !$0.paused && $0.reminderHour != nil } }

    func reload() {
        now = Date()
        do { state = try ChecklistStore.shared().read() }
        catch { self.error = error.localizedDescription }
    }

    func refresh() async {
        reload()
        await syncReminders()
    }

    func tick() {
        let dayChanged = Day.key(now) != Day.key(Date())
        reload()
        if dayChanged { Task { await syncReminders(); WidgetCenter.shared.reloadAllTimelines() } }
    }

    @discardableResult
    private func mutate(_ action: (inout ChecklistState) -> Void) -> Bool {
        do {
            state = try ChecklistStore.shared().update(action)
            now = Date()
            WidgetCenter.shared.reloadAllTimelines()
            Task { await syncReminders() }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func complete(_ item: ChecklistItem) { _ = mutate { $0.complete(item.id) } }
    func undo(_ item: ChecklistItem) { _ = mutate { $0.undo(item.id) } }
    func pause(_ item: ChecklistItem) {
        _ = mutate { state in
            if let i = state.items.firstIndex(where: { $0.id == item.id }) { state.items[i].paused.toggle() }
        }
    }
    func delete(_ item: ChecklistItem) { _ = mutate { $0.items.removeAll { $0.id == item.id } } }

    func save(_ item: ChecklistItem, isNew: Bool) -> Bool {
        mutate { state in
            if let i = state.items.firstIndex(where: { $0.id == item.id }) {
                // Keep completions that may have been changed by a widget while the editor was open.
                var edited = item
                edited.completedDays = state.items[i].completedDays
                edited.paused = state.items[i].paused
                state.items[i] = edited
            } else if isNew { state.items.append(item) }
        }
    }

    func enableNotifications() async {
        do { _ = try await ReminderScheduler.shared.requestPermission() }
        catch { self.error = error.localizedDescription }
        await syncReminders()
    }

    func syncReminders() async {
        do { try await ReminderScheduler.shared.sync() }
        catch { self.error = "清单已保存，但提醒未能同步：\(error.localizedDescription)" }
        let center = UNUserNotificationCenter.current()
        notificationStatus = await center.notificationSettings().authorizationStatus
        let requests = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("daylist.") }
        pendingCount = requests.count
        lastReminderDate = requests.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.max()
    }
}
