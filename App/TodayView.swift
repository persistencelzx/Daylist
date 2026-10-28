import SwiftUI

enum Palette {
    static let green = Color(red: 0.23, green: 0.37, blue: 0.30)
    static let mint = Color(red: 0.88, green: 0.93, blue: 0.85)
    static let paper = Color(uiColor: .systemGroupedBackground)
}

struct EditorRoute: Identifiable {
    let id = UUID()
    var item: ChecklistItem?
}

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection = 0
    @State private var editor: EditorRoute?
    @State private var showSettings = false
    @State private var showCompleted = false
    @State private var deleting: ChecklistItem?
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if selection == 0 { progressCard }
                    Picker("清单视图", selection: $selection) {
                        Text("今天").tag(0)
                        Text("全部事项").tag(1)
                    }.pickerStyle(.segmented)
                    if selection == 0 { todayList } else { allList }
                    if selection == 0 && model.hasReminders && model.notificationStatus == .denied {
                        Button { showSettings = true } label: {
                            Label("通知未开启，点此查看提醒设置", systemImage: "bell.slash")
                                .font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("把每一天，过成喜欢的样子。")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .padding(.horizontal, 24).padding(.top, 12)
            }
            .background(Palette.paper)
            .safeAreaInset(edge: .bottom) {
                Button { editor = EditorRoute() } label: {
                    Label("添加事项", systemImage: "plus")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                }
                .buttonStyle(.plain).foregroundStyle(.white)
                .background(Palette.green, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Label("每日清单", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.green)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("设置与小组件帮助")
                }
            }
            .sheet(item: $editor) { route in ItemEditor(item: route.item) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .alert("需要留意", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("知道了", role: .cancel) { model.error = nil }
            } message: { Text(model.error ?? "") }
            .confirmationDialog("删除「\(deleting?.title ?? "")」及其完成记录？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                if let item = deleting {
                    Button("删除事项", role: .destructive) { model.delete(item); deleting = nil }
                }
                Button("取消", role: .cancel) { deleting = nil }
            }
            .onReceive(ticker) { _ in model.tick() }
            .onOpenURL { _ in selection = 0; model.reload() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                .font(.subheadline).foregroundStyle(.secondary)
            Text(selection == 0 ? "今天，慢慢来。" : "让好习惯发生。")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(selection == 0 ? "完成一件，就轻一点。" : "管理每天重复的小事，也记住偶尔的待办。")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var progressCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Label("今日进度", systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                (Text("\(model.completed.count)").font(.system(size: 38, weight: .semibold, design: .rounded))
                 + Text(" / \(model.today.count) 件").font(.subheadline))
                Text(model.today.isEmpty ? "给今天安排一件小事吧" : model.pending.isEmpty ? "今天的小事，都做好了 ✨" : "还有 \(model.pending.count) 件小事，等你完成")
                    .font(.caption)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.white.opacity(0.45), lineWidth: 9)
                Circle().trim(from: 0, to: model.today.isEmpty ? 0 : CGFloat(model.completed.count) / CGFloat(model.today.count))
                    .stroke(Palette.green, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: model.pending.isEmpty && !model.today.isEmpty ? "checkmark" : "leaf.fill")
                    .font(.system(size: 25, weight: .medium))
            }.frame(width: 76, height: 76).accessibilityHidden(true)
        }
        .foregroundStyle(Palette.green).padding(24)
        .background(Palette.mint, in: RoundedRectangle(cornerRadius: 26))
        .animation(.easeInOut(duration: 0.25), value: model.completed.count)
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("待完成").font(.headline)
                Text("\(model.pending.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("勾选后从今天移除").font(.caption).foregroundStyle(.secondary)
            }
            if model.pending.isEmpty {
                emptyState(title: model.today.isEmpty ? "今天，从一件小事开始" : "今日清单已完成", subtitle: model.today.isEmpty ? "试试添加「吃鱼油」，设为每天重复。" : "休息一下吧。每日事项明天会再出现。", symbol: "sun.max")
            }
            ForEach(model.pending) { item in itemRow(item, mode: .pending) }
            if !model.completed.isEmpty {
                DisclosureGroup(isExpanded: $showCompleted) {
                    VStack(spacing: 10) {
                        ForEach(model.completed) { item in itemRow(item, mode: .completed) }
                    }.padding(.top, 12)
                } label: {
                    Text("今日已完成 · \(model.completed.count)").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 12)
            }
        }
    }

    private var allList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("所有事项 · \(model.state.items.count)").font(.headline)
            if model.state.items.isEmpty {
                emptyState(title: "留一点位置给好习惯", subtitle: "每天重复、定时提醒，都从这里开始。", symbol: "sprout")
            }
            ForEach(model.state.items.sorted { $0.createdAt < $1.createdAt }) { item in itemRow(item, mode: .manage) }
        }
    }

    private enum RowMode { case pending, completed, manage }

    private func itemRow(_ item: ChecklistItem, mode: RowMode) -> some View {
        HStack(spacing: 14) {
            if mode != .manage {
                Button {
                    withAnimation(.snappy) {
                        if mode == .completed { model.undo(item) } else { model.complete(item) }
                    }
                } label: {
                    Image(systemName: mode == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(mode == .completed ? Palette.green : Color.secondary.opacity(0.5))
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain)
                    .accessibilityLabel(mode == .completed ? "撤销完成：\(item.title)" : "完成：\(item.title)")
            } else {
                Image(systemName: item.symbol).font(.title3).foregroundStyle(Palette.green)
                    .frame(width: 42, height: 44).background(Palette.mint.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
            }
            Button { editor = EditorRoute(item: item) } label: {
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                        .strikethrough(mode == .completed).multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Label(item.rule == .daily ? "每天" : "仅一次", systemImage: item.rule == .daily ? "repeat" : "calendar")
                        if let time = item.timeLabel { Text(time).monospacedDigit() }
                        if item.paused { Text("已暂停") }
                        else if mode == .manage && item.rule == .once && !item.completedDays.isEmpty { Text("已完成") }
                    }.font(.caption2).foregroundStyle(.secondary)
                    if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Menu {
                Button("编辑", systemImage: "pencil") { editor = EditorRoute(item: item) }
                Button(item.paused ? "恢复事项" : "暂停事项", systemImage: item.paused ? "play" : "pause") { model.pause(item) }
                Button("删除", systemImage: "trash", role: .destructive) { deleting = item }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.secondary).frame(width: 32, height: 44)
            }.accessibilityLabel("\(item.title)的更多操作")
        }
        .padding(.horizontal, 12).padding(.vertical, 13)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func emptyState(title: String, subtitle: String, symbol: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 36, weight: .light)).foregroundStyle(Palette.green)
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 36)
    }
}
