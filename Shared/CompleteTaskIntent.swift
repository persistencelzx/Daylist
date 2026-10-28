import AppIntents
import WidgetKit

// LiveActivityIntent executes in the containing app process, including from a widget.
// This keeps notification scheduling in the app's notification center.
struct CompleteTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "完成今日事项"
    static var description = IntentDescription("完成今天的事项，每日重复事项将在明天重新出现。")
    static var openAppWhenRun = false

    @Parameter(title: "事项 ID") var itemID: String
    @Parameter(title: "清单日期") var dayKey: String

    init() {}
    init(itemID: String, dayKey: String) { self.itemID = itemID; self.dayKey = dayKey }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let id = UUID(uuidString: itemID) else { return .result(dialog: "事项不存在。") }
        // A stale widget from yesterday must never complete today's occurrence.
        guard dayKey == Day.key(Date()) else {
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: "清单日期已更新，请重新勾选。")
        }
        do {
            try ChecklistStore.shared().update { $0.complete(id) }
        } catch {
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: "保存失败，请打开每日清单检查共享数据配置。")
        }
        WidgetCenter.shared.reloadAllTimelines()
        do { try await ReminderScheduler.shared.sync() }
        catch { return .result(dialog: "已完成；提醒同步失败，请打开每日清单重试。") }
        return .result(dialog: "已完成今天的事项。")
    }
}
