// ============================================================
// RemindersView.swift —— 提醒管理界面（功能 4 的界面部分）
// 上半部分：添加新提醒（事件名 + 日期）
// 下半部分：提醒列表（可勾选完成、可删除）
// ============================================================
import SwiftUI

struct RemindersView: View {
    // 共用那个全局唯一的数据仓库；它一变，这个界面自动刷新
    @ObservedObject var store = ReminderStore.shared

    @State private var newTitle = ""                                  // 输入框内容
    @State private var newDate = Date().addingTimeInterval(3600)      // 默认 1 小时后

    // 常见的猫咪事件，一键填入
    let presets = ["内驱", "外驱", "疫苗", "剪指甲", "洗澡", "铲屎", "喂罐头"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ---- 添加区域 ----
            Text("添加提醒").font(.headline)

            HStack {
                TextField("事件名称，如：内驱", text: $newTitle)
                    .textFieldStyle(.roundedBorder)

                DatePicker("", selection: $newDate)
                    .labelsHidden()   // 不显示"日期"标签，省地方

                Button("添加") {
                    let title = newTitle.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    store.add(title: title, dueDate: newDate)
                    newTitle = ""   // 清空输入框
                }
                .keyboardShortcut(.return)   // 按回车也能添加
            }

            // ---- 快捷按钮：点一下自动填入事件名 ----
            HStack {
                ForEach(presets, id: \.self) { p in
                    Button(p) { newTitle = p }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            Divider()

            // ---- 列表区域 ----
            Text("全部提醒").font(.headline)

            if store.reminders.isEmpty {
                Text("还没有提醒，添加一个吧 🐾")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 30)
            }

            List {
                ForEach(store.reminders) { reminder in
                    HStack {
                        // 完成勾选框
                        Button {
                            store.toggleDone(reminder)
                        } label: {
                            Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(reminder.isDone ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading) {
                            Text(reminder.title)
                                .strikethrough(reminder.isDone)   // 完成的画删除线
                            Text(reminder.dueDate, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption)
                                .foregroundColor(isOverdue(reminder) ? .red : .secondary)
                        }

                        Spacer()

                        // 删除按钮
                        Button {
                            store.delete(reminder)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)
        }
        .padding()
        .frame(minWidth: 460, minHeight: 400)
    }

    // 过期且没完成 → 红字显示
    func isOverdue(_ r: Reminder) -> Bool {
        r.dueDate < Date() && !r.isDone
    }
}
