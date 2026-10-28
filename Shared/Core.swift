import Foundation

enum Day {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

enum RepeatRule: String, Codable, CaseIterable {
    case daily, once
    var title: String { self == .daily ? "每天重复" : "仅一次" }
}

struct ChecklistItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var note = ""
    var symbol = "sparkles"
    var rule: RepeatRule = .daily
    var startDay: String
    var reminderHour: Int?
    var reminderMinute = 0
    var paused = false
    var completedDays: Set<String> = []
    var createdAt = Date()

    func isComplete(on date: Date, calendar: Calendar = .current) -> Bool {
        completedDays.contains(Day.key(date, calendar: calendar))
    }

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = Day.key(date, calendar: calendar)
        guard !paused, startDay <= day else { return false }
        return rule == .daily || completedDays.isEmpty || completedDays.contains(day)
    }

    func isPending(on date: Date, calendar: Calendar = .current) -> Bool {
        isScheduled(on: date, calendar: calendar) && !isComplete(on: date, calendar: calendar)
    }

    var timeLabel: String? {
        reminderHour.map { String(format: "%02d:%02d", $0, reminderMinute) }
    }
}

struct ChecklistState: Codable, Equatable {
    var schemaVersion = 1
    var items: [ChecklistItem] = []

    func today(_ date: Date = Date(), calendar: Calendar = .current) -> [ChecklistItem] {
        items.filter { $0.isScheduled(on: date, calendar: calendar) }.sorted {
            let left = ($0.reminderHour ?? 24) * 60 + $0.reminderMinute
            let right = ($1.reminderHour ?? 24) * 60 + $1.reminderMinute
            return left == right ? $0.createdAt < $1.createdAt : left < right
        }
    }

    mutating func complete(_ id: UUID, on date: Date = Date(), calendar: Calendar = .current) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].isPending(on: date, calendar: calendar) else { return }
        items[index].completedDays.insert(Day.key(date, calendar: calendar))
    }

    mutating func undo(_ id: UUID, on date: Date = Date(), calendar: Calendar = .current) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].completedDays.remove(Day.key(date, calendar: calendar))
    }
}
