import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 42)).foregroundStyle(Palette.green)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("每日清单").font(.title3.bold())
                            Text("小事有序，每天轻一点。\n版本 1.0 · 数据保存在本机")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 10)
                }
                Section("提醒") {
                    LabeledContent("通知权限", value: statusLabel)
                    if model.notificationStatus == .notDetermined {
                        Button("开启提醒通知") { Task { await model.enableNotifications() } }
                    } else {
                        Button("打开系统通知设置") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    LabeledContent("已安排提醒", value: "\(model.pendingCount) 条")
                    if let last = model.lastReminderDate {
                        LabeledContent("最晚一条", value: last.formatted(.dateTime.month().day().hour().minute()))
                    }
                    Button("立即更新提醒计划") { Task { await model.syncReminders() } }
                }
                Section {
                    Text("为让已完成事项当天不再提醒，App 按日期提前安排最近 60 条通知。打开 App、勾选小组件或系统允许后台刷新时，会自动补充。")
                    Text("如果长时间不打开 App 或操作小组件，已安排的提醒用尽后将暂停。后台刷新和通知展示由 iOS 控制；请定期打开 App，并留意专注模式与通知权限。")
                } header: { Text("提醒范围") }
                    .font(.footnote).foregroundStyle(.secondary)
                Section("添加桌面小组件") {
                    Label("长按 iPhone 主屏幕空白处", systemImage: "1.circle")
                    Label("进入编辑，选择「添加小组件」", systemImage: "2.circle")
                    Label("搜索「每日清单」，选择尺寸并添加", systemImage: "3.circle")
                    Label("点事项左侧的圆圈即可完成", systemImage: "4.circle")
                    Text("支持小、中、大尺寸。小组件展示待完成事项；完成后移除，每日事项第二天重新出现。更多事项可点底部打开 App。午夜刷新时间由系统调度，已预生成后续日期的清单。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("数据与隐私") {
                    Text("无需登录、无需服务器，不采集个人数据。App 与桌面小组件仅通过本机 App Group 共享清单。卸载 App 可能清除数据。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置与帮助").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task { await model.syncReminders() }
        }
    }

    private var statusLabel: String {
        switch model.notificationStatus {
        case .authorized: return "已开启"
        case .provisional: return "静默通知"
        case .ephemeral: return "临时允许"
        case .denied: return "未开启"
        case .notDetermined: return "尚未设置"
        @unknown default: return "请检查系统设置"
        }
    }
}
