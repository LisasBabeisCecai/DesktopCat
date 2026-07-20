// ============================================================
// CareView.swift —— 养护周期提醒界面
//
// 展示 6 个养护任务卡片：
//   - 任务名、周期、下次到期日、倒计时天数
//   - "完成"按钮：标记今天完成，自动算下一次
//   - "设置日期"：手动指定上一次完成的日期
// ============================================================
import SwiftUI

struct CareView: View {
    @ObservedObject var store = ReminderStore.shared
    @State private var editingTask: CareTask? = nil
    @State private var pickedDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🐾 养护周期提醒").font(.title2).bold()
            Text("标记完成后，系统会自动计算下一次到期时间")
                .font(.caption).foregroundColor(.secondary)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.careTasks) { task in
                        CareTaskRow(task: task,
                                    onComplete: { store.completeTask(task) },
                                    onSetDate: {
                                        editingTask = task
                                        pickedDate = Date()
                                    })
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 380)
        .sheet(item: $editingTask) { task in
            VStack(spacing: 16) {
                Text("设置「\(task.type)」上次完成日期").font(.headline)
                Text("系统会从这天起算 \(task.interval) 天后提醒你")
                    .font(.caption).foregroundColor(.secondary)

                DatePicker("完成日期", selection: $pickedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)

                HStack {
                    Button("取消") { editingTask = nil }
                        .keyboardShortcut(.escape)
                    Spacer()
                    Button("确认") {
                        store.setFirstDate(task, date: pickedDate)
                        editingTask = nil
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 340, height: 380)
        }
    }
}

// 单个任务卡片
struct CareTaskRow: View {
    let task: CareTask
    let onComplete: () -> Void
    let onSetDate: () -> Void

    var body: some View {
        HStack {
            // 左侧：任务信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(iconFor(task.type))
                    Text(task.type).font(.headline)
                    Text("每\(intervalText)").font(.caption)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(.gray.opacity(0.15)))
                }

                HStack(spacing: 4) {
                    Text("下次：")
                        .font(.caption).foregroundColor(.secondary)
                    Text(task.nextDue, format: .dateTime.month().day())
                        .font(.caption).bold()
                        .foregroundColor(isOverdue ? .red : .primary)

                    if isOverdue {
                        Text("已逾期\(overdueDays)天")
                            .font(.caption).foregroundColor(.red)
                    } else {
                        Text("还有\(daysLeft)天")
                            .font(.caption).foregroundColor(isUrgent ? .orange : .green)
                    }
                }
            }

            Spacer()

            // 右侧：按钮
            VStack(spacing: 6) {
                Button("✓ 完成") { onComplete() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(isOverdue ? .red : isUrgent ? .orange : .blue)

                Button("设置日期") { onSetDate() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(cardBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(cardBorderColor))
    }

    var isOverdue: Bool { task.nextDue < Date() }
    var isUrgent: Bool { !isOverdue && daysLeft <= 3 }  // 3天内临期

    var cardBackgroundColor: Color {
        if isOverdue { return Color.red.opacity(0.08) }
        if isUrgent { return Color.orange.opacity(0.08) }
        return Color.gray.opacity(0.05)
    }

    var cardBorderColor: Color {
        if isOverdue { return Color.red.opacity(0.4) }
        if isUrgent { return Color.orange.opacity(0.4) }
        return Color.gray.opacity(0.15)
    }

    var daysLeft: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: task.nextDue).day ?? 0
        return max(diff, 0)
    }

    var overdueDays: Int {
        let diff = Calendar.current.dateComponents([.day], from: task.nextDue, to: Date()).day ?? 0
        return max(diff, 0)
    }

    var intervalText: String {
        if task.interval == 7 { return "周" }
        if task.interval == 30 { return "月" }
        if task.interval == 60 { return "两月" }
        if task.interval == 90 { return "三月" }
        return "\(task.interval)天"
    }

    func iconFor(_ type: String) -> String {
        switch type {
        case "剪指甲": return "✂️"
        case "掏耳朵": return "👂"
        case "外驱": return "🛡️"
        case "内驱": return "💊"
        case "换猫砂": return "🚽"
        case "深度梳毛": return "🪮"
        default: return "🐱"
        }
    }
}
