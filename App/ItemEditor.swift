import SwiftUI

struct ItemEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private let original: ChecklistItem?
    @State private var title: String
    @State private var note: String
    @State private var rule: RepeatRule
    @State private var symbol: String
    @State private var reminderEnabled: Bool
    @State private var time: Date
    @State private var startDate: Date
    @State private var saving = false
    @State private var saveError: String?
    @FocusState private var titleFocused: Bool
    private let symbols = ["sparkles", "pills", "drop", "figure.walk", "book", "heart", "cup.and.saucer", "moon"]

    init(item: ChecklistItem?) {
        original = item
        _title = State(initialValue: item?.title ?? "")
        _note = State(initialValue: item?.note ?? "")
        _rule = State(initialValue: item?.rule ?? .daily)
        _symbol = State(initialValue: item?.symbol ?? "sparkles")
        _reminderEnabled = State(initialValue: item?.reminderHour != nil)
        _time = State(initialValue: Calendar.current.date(bySettingHour: item?.reminderHour ?? 9, minute: item?.reminderMinute ?? 0, second: 0, of: Date()) ?? Date())
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        _startDate = State(initialValue: item.flatMap { formatter.date(from: $0.startDay) } ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("想完成什么？") {
                    TextField("例如：吃鱼油", text: $title).focused($titleFocused)
                        .onChange(of: title) { _, value in if value.count > 80 { title = String(value.prefix(80)) } }
                    TextField("备注（可选）", text: $note, axis: .vertical).lineLimit(2...4)
                        .onChange(of: note) { _, value in if value.count > 500 { note = String(value.prefix(500)) } }
                }
                Section("给小事一个图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(symbols, id: \.self) { value in
                            Button { symbol = value } label: {
                                Image(systemName: value).font(.title3).frame(maxWidth: .infinity).frame(height: 44)
                                    .background(symbol == value ? Palette.mint : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).foregroundStyle(Palette.green)
                                .accessibilityLabel(symbolName(value))
                                .accessibilityAddTraits(symbol == value ? .isSelected : [])
                        }
                    }.padding(.vertical, 4)
                }
                Section {
                    Picker("重复", selection: $rule) {
                        ForEach(RepeatRule.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    DatePicker(rule == .daily ? "开始日期" : "计划日期", selection: $startDate, displayedComponents: .date)
                } footer: {
                    Text(rule == .daily ? "今天勾选后隐藏，明天自动重新出现。不会累积昨天未完成的副本。" : "未完成的事项会保留在清单中，完成后不再重复。")
                }
                Section {
                    Toggle("定时提醒", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("提醒时间", selection: $time, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("使用手机当地时间。当天提前完成后，会取消当天待发送的提醒。")
                }
            }
            .navigationTitle(original == nil ? "添加一件小事" : "编辑事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中…" : "保存") { Task { await save() } }
                        .fontWeight(.semibold).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                }
            }
            .interactiveDismissDisabled(saving)
            .alert("未能保存", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("好", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    private func symbolName(_ symbol: String) -> String {
        ["sparkles": "日常", "pills": "营养补充", "drop": "喝水", "figure.walk": "运动", "book": "阅读", "heart": "健康", "cup.and.saucer": "休息", "moon": "睡眠"][symbol] ?? symbol
    }

    @MainActor
    private func save() async {
        saving = true
        defer { saving = false }
        var item = original ?? ChecklistItem(title: "", startDay: Day.key(startDate))
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        item.rule = rule
        item.symbol = symbol
        item.startDay = Day.key(startDate)
        item.reminderHour = reminderEnabled ? Calendar.current.component(.hour, from: time) : nil
        item.reminderMinute = Calendar.current.component(.minute, from: time)
        guard model.save(item, isNew: original == nil) else {
            saveError = model.error ?? "请稍后再试。"
            model.error = nil
            return
        }
        if reminderEnabled { await model.enableNotifications() }
        dismiss()
    }
}
