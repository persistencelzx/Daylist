#if PORTABLE_TESTS
import Foundation
#else
import XCTest
@testable import DaylistCore
#endif

final class DaylistCoreTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return result
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private var today: Date { date("2026-10-27T10:00:00+08:00") }
    private var tomorrow: Date { date("2026-10-28T10:00:00+08:00") }
    private func item(rule: RepeatRule = .daily) -> ChecklistItem {
        ChecklistItem(title: "吃鱼油", rule: rule, startDay: "2026-10-27", reminderHour: 12)
    }

    func testCompletionHidesTodayAndReturnsTomorrow() {
        let task = item()
        var state = ChecklistState(items: [task])
        state.complete(task.id, on: today, calendar: calendar)
        XCTAssertFalse(state.items[0].isPending(on: today, calendar: calendar))
        XCTAssertTrue(state.items[0].isPending(on: tomorrow, calendar: calendar))
        XCTAssertEqual(state.items[0].completedDays, ["2026-10-27"])
    }

    func testCompletionIsIdempotentAndUndoIsDateScoped() {
        let task = item()
        var state = ChecklistState(items: [task])
        state.complete(task.id, on: today, calendar: calendar)
        state.complete(task.id, on: today, calendar: calendar)
        state.complete(task.id, on: tomorrow, calendar: calendar)
        state.undo(task.id, on: tomorrow, calendar: calendar)
        XCTAssertEqual(state.items[0].completedDays, ["2026-10-27"])
        XCTAssertTrue(state.items[0].isPending(on: tomorrow, calendar: calendar))
    }

    func testOneOffDoesNotReappearButUnfinishedCarriesForward() {
        let task = item(rule: .once)
        var state = ChecklistState(items: [task])
        XCTAssertTrue(task.isPending(on: tomorrow, calendar: calendar))
        state.complete(task.id, on: today, calendar: calendar)
        XCTAssertTrue(state.items[0].isScheduled(on: today, calendar: calendar))
        XCTAssertFalse(state.items[0].isScheduled(on: tomorrow, calendar: calendar))
    }

    func testPausedAndFutureItemsAreNotCompletable() {
        var paused = item()
        paused.paused = true
        var future = item()
        future.startDay = "2026-11-01"
        var state = ChecklistState(items: [paused, future])
        state.complete(paused.id, on: today, calendar: calendar)
        state.complete(future.id, on: today, calendar: calendar)
        XCTAssertTrue(state.today(today, calendar: calendar).isEmpty)
        XCTAssertTrue(state.items.allSatisfy { $0.completedDays.isEmpty })
    }

    func testLocalMidnightRatherThan24HourInterval() {
        let task = item()
        let before = date("2026-10-27T23:59:59+08:00")
        let after = date("2026-10-28T00:00:01+08:00")
        var state = ChecklistState(items: [task])
        state.complete(task.id, on: before, calendar: calendar)
        XCTAssertTrue(state.items[0].isPending(on: after, calendar: calendar))
    }

    func testDayKeysUseGregorianYearEvenInBuddhistCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        XCTAssertEqual(Day.key(today, calendar: buddhist), "2026-10-27")
    }

    func testTimeZoneUsesCurrentLocalDay() {
        var losAngeles = calendar
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(Day.key(today, calendar: losAngeles), "2026-10-26")
    }

    func testCompletedDayReminderRemovedAndFutureRetained() {
        let task = item()
        var state = ChecklistState(items: [task])
        XCTAssertEqual(ReminderPlan.build(state: state, now: today, calendar: calendar, horizon: 3).count, 3)
        state.complete(task.id, on: today, calendar: calendar)
        let plan = ReminderPlan.build(state: state, now: today, calendar: calendar, horizon: 3)
        XCTAssertEqual(plan.map(\.dayKey), ["2026-10-28", "2026-10-29"])
    }

    func testReminderLimitIsChronologicalAcrossAllItems() {
        var tasks = (0..<10).map { index -> ChecklistItem in
            var task = item()
            task.title = "事项 \(index)"
            task.reminderHour = index + 11
            return task
        }
        tasks.reverse()
        let plan = ReminderPlan.build(state: ChecklistState(items: tasks), now: today, calendar: calendar)
        XCTAssertEqual(plan.count, 60)
        XCTAssertEqual(plan.first?.title, "事项 0")
        XCTAssertEqual(plan.last?.dayKey, "2026-11-01")
        XCTAssertEqual(Set(plan.map(\.identifier)).count, 60)
    }

    func testOneOffReminderNeverRepeatsAndPastReminderIsNotResent() {
        let task = item(rule: .once)
        XCTAssertEqual(ReminderPlan.build(state: ChecklistState(items: [task]), now: today, calendar: calendar).count, 1)
        XCTAssertTrue(ReminderPlan.build(state: ChecklistState(items: [task]), now: tomorrow, calendar: calendar).isEmpty)
    }

    func testDisabledAndPausedRemindersAreExcluded() {
        var noTime = item()
        noTime.reminderHour = nil
        var paused = item()
        paused.paused = true
        XCTAssertTrue(ReminderPlan.build(state: ChecklistState(items: [noTime, paused]), now: today, calendar: calendar).isEmpty)
    }

    func testDSTSpringForwardProducesOneReminderPerLocalDate() {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        var task = item()
        task.startDay = "2026-03-07"
        task.reminderHour = 2
        task.reminderMinute = 30
        let plan = ReminderPlan.build(state: ChecklistState(items: [task]), now: date("2026-03-07T00:00:00-05:00"), calendar: ny, horizon: 3)
        XCTAssertEqual(plan.map(\.dayKey), ["2026-03-07", "2026-03-08", "2026-03-09"])
        XCTAssertEqual(Set(plan.map(\.date)).count, 3)
        XCTAssertEqual(ny.component(.hour, from: plan[1].date), 3)
    }

    func testDSTFallBackDoesNotDuplicateReminder() {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        var task = item()
        task.startDay = "2026-11-01"
        task.reminderHour = 1
        task.reminderMinute = 30
        let plan = ReminderPlan.build(state: ChecklistState(items: [task]), now: date("2026-11-01T00:00:00-04:00"), calendar: ny, horizon: 1)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].date, date("2026-11-01T01:30:00-04:00"))
    }

    func testStoragePersistsCompletionAndDoesNotLoseConcurrentEdits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ChecklistStore(directory: directory)
        let tasks = (0..<40).map { _ in item() }
        try store.update { $0.items = tasks }
        let today = today
        let calendar = calendar
        let errors = ErrorCollector()
        DispatchQueue.concurrentPerform(iterations: tasks.count) { index in
            do { try store.update { $0.complete(tasks[index].id, on: today, calendar: calendar) } }
            catch { errors.record(error) }
        }
        XCTAssertEqual(errors.count, 0)
        let restored = try ChecklistStore(directory: directory).read()
        XCTAssertEqual(restored.items.count, 40)
        XCTAssertTrue(restored.items.allSatisfy { $0.isComplete(on: today, calendar: calendar) })
    }

    func testCorruptOrNewerDataIsNeverOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("checklist.json")
        let corrupt = Data("damaged".utf8)
        try corrupt.write(to: url)
        let store = ChecklistStore(directory: directory)
        XCTAssertThrowsError(try store.update { $0.items = [] })
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        let newer = Data(#"{"schemaVersion":2,"items":[]}"#.utf8)
        try newer.write(to: url)
        XCTAssertThrowsError(try store.update { $0.items = [] })
        XCTAssertEqual(try Data(contentsOf: url), newer)
    }
}

private final class ErrorCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [Error] = []
    func record(_ error: Error) { lock.lock(); defer { lock.unlock() }; errors.append(error) }
    var count: Int { lock.lock(); defer { lock.unlock() }; return errors.count }
}
