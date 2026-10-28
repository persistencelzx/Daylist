import SwiftUI
import UserNotifications
import BackgroundTasks
import WidgetKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var refreshIdentifier: String { (Bundle.main.bundleIdentifier ?? "") + ".refresh" }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: nil) { task in
            let work = Task {
                do {
                    try Task.checkCancellation()
                    try await ReminderScheduler.shared.sync()
                    WidgetCenter.shared.reloadAllTimelines()
                    task.setTaskCompleted(success: !Task.isCancelled)
                } catch { task.setTaskCompleted(success: false) }
                Self.scheduleRefresh()
            }
            task.expirationHandler = { work.cancel() }
        }
        return true
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        // Background refresh is best effort; foreground/widget interactions also replenish reminders.
        try? BGTaskScheduler.shared.submit(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let id = notification.request.content.userInfo["itemID"] as? String,
           let day = notification.request.content.userInfo["day"] as? String,
           let state = try? ChecklistStore.shared().read() {
            guard let item = state.items.first(where: { $0.id.uuidString == id }),
                  !item.paused, !item.completedDays.contains(day) else { return [] }
        }
        return [.banner, .sound]
    }
}

@main
struct DaylistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environmentObject(model)
                .tint(Palette.green)
                .task { await model.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.refresh() } }
                    if phase == .background { AppDelegate.scheduleRefresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await model.refresh(); WidgetCenter.shared.reloadAllTimelines() }
                }
        }
    }
}
