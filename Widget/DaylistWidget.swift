import SwiftUI
import WidgetKit
import AppIntents

struct ChecklistEntry: TimelineEntry {
    let date: Date
    let state: ChecklistState
    var unavailable = false
    var pending: [ChecklistItem] { state.today(date).filter { !$0.isComplete(on: date) } }
    var completedCount: Int { state.today(date).count - pending.count }
}

struct ChecklistProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChecklistEntry { sample() }
    func getSnapshot(in context: Context, completion: @escaping (ChecklistEntry) -> Void) {
        if context.isPreview { completion(sample()); return }
        completion(load(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChecklistEntry>) -> Void) {
        let now = Date()
        let first = load(at: now)
        var entries = [first]
        let calendar = Calendar.current
        // Midnight entries are generated in advance; a late provider refresh doesn't retain yesterday's completions.
        for offset in 1...7 {
            if let next = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) {
                entries.append(ChecklistEntry(date: next, state: first.state, unavailable: first.unavailable))
            }
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
    }

    private func load(at date: Date) -> ChecklistEntry {
        do { return ChecklistEntry(date: date, state: try ChecklistStore.shared().read()) }
        catch { return ChecklistEntry(date: date, state: ChecklistState(), unavailable: true) }
    }

    private func sample() -> ChecklistEntry {
        let day = Day.key(Date())
        return ChecklistEntry(date: Date(), state: ChecklistState(items: [
            ChecklistItem(title: "吃鱼油", symbol: "pills", startDay: day, reminderHour: 9),
            ChecklistItem(title: "读 10 页书", symbol: "book", startDay: day, reminderHour: 20),
            ChecklistItem(title: "睡前拉伸", symbol: "figure.walk", startDay: day, reminderHour: 22)
        ]))
    }
}

struct ChecklistWidgetView: View {
    let entry: ChecklistEntry
    @Environment(\.widgetFamily) private var family
    private let green = Color(red: 0.23, green: 0.37, blue: 0.30)
    private var limit: Int { family == .systemLarge ? 7 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("每日清单", systemImage: "leaf.fill").font(.caption.weight(.semibold))
                Spacer(minLength: 2)
                if family != .systemSmall {
                    Text(entry.date.formatted(.dateTime.month().day())).font(.caption2)
                }
            }.foregroundStyle(green)
            if entry.unavailable {
                Spacer(minLength: 0)
                Text("打开 App 同步清单").font(.subheadline.weight(.medium))
                Text("共享数据暂不可用").font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if entry.pending.isEmpty {
                Spacer(minLength: 0)
                Image(systemName: "sun.max").font(.title2).foregroundStyle(green)
                Text(entry.completedCount > 0 ? "今天，都做好了" : "今天的小事").font(.headline)
                Text(entry.completedCount > 0 ? "每日事项明天再见" : "打开 App 添加第一件事").font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(entry.pending.prefix(limit))) { item in
                    HStack(spacing: 8) {
                        Button(intent: CompleteTaskIntent(itemID: item.id.uuidString, dayKey: Day.key(entry.date))) {
                            Image(systemName: "circle").font(.system(size: 23, weight: .light))
                                .frame(width: 30, height: 30).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).tint(green)
                        .accessibilityLabel("完成：\(item.title)")
                        Text(item.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            .invalidatableContent()
                        Spacer(minLength: 0)
                        if family != .systemSmall, let time = item.timeLabel {
                            Text(time).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Link(destination: URL(string: "daylist://today")!) {
                    HStack {
                        Text(entry.pending.count > limit ? "还有 \(entry.pending.count - limit) 件 · 查看全部" : "待完成 \(entry.pending.count) 件")
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                    }.font(.caption2).foregroundStyle(green)
                }
            }
        }
        .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        .widgetURL(URL(string: "daylist://today"))
    }
}

@main
struct DaylistWidget: Widget {
    let kind = "DaylistWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChecklistProvider()) { entry in ChecklistWidgetView(entry: entry) }
            .configurationDisplayName("每日清单")
            .description("在桌面看看今天的小事，轻点圆圈即可完成。")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
