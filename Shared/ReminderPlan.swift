import Foundation

struct PlannedReminder: Equatable {
    let itemID: UUID
    let title: String
    let date: Date
    let dayKey: String
    var identifier: String { "daylist.\(itemID.uuidString).\(dayKey)" }
}

enum ReminderPlan {
    /// Reserve four of iOS's notification slots. Keep the soonest reminders across all tasks.
    static func build(state: ChecklistState, now: Date = Date(), calendar: Calendar = .current,
                      limit: Int = 60, horizon: Int = 90) -> [PlannedReminder] {
        var result: [PlannedReminder] = []
        let today = calendar.startOfDay(for: now)
        for offset in 0..<horizon {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            for item in state.items where item.isPending(on: day, calendar: calendar) {
                guard let hour = item.reminderHour, (0...23).contains(hour), (0...59).contains(item.reminderMinute),
                      let date = calendar.date(bySettingHour: hour, minute: item.reminderMinute, second: 0,
                                               of: day, matchingPolicy: .nextTime,
                                               repeatedTimePolicy: .first, direction: .forward), date > now else { continue }
                // A one-off task gets one reminder, never a daily reminder after it is overdue.
                guard item.rule == .daily || item.startDay == Day.key(day, calendar: calendar) else { continue }
                result.append(PlannedReminder(itemID: item.id, title: item.title, date: date,
                                              dayKey: Day.key(day, calendar: calendar)))
            }
        }
        return Array(result.sorted {
            $0.date == $1.date ? $0.identifier < $1.identifier : $0.date < $1.date
        }.prefix(max(0, limit)))
    }
}
