// ============================================================
// ReminderStore.swift —— 本地数据库（提醒 + 养护周期）
//
// 用的是 SQLite：一个"单文件数据库"，macOS 系统自带，不用安装。
// 数据存在 ~/Library/Application Support/DesktopCat/reminders.db
// ============================================================
import Foundation
import SQLite3
import AppKit

// 一条普通提醒
struct Reminder: Identifiable {
    let id: Int64
    var title: String
    var dueDate: Date
    var isDone: Bool
    var notified: Bool
}

// 一条周期养护任务
struct CareTask: Identifiable {
    let id: Int64
    var type: String        // "剪指甲"/"掏耳朵"/"外驱"/"内驱"/"换猫砂"/"深度梳毛"
    var interval: Int       // 周期天数
    var nextDue: Date       // 下次到期时间
    var lastNotifiedDate: String  // 上次提醒的日期字符串 "2026-07-09"，当天已提醒就不再弹
}

class ReminderStore: ObservableObject {
    static let shared = ReminderStore()

    @Published var reminders: [Reminder] = []
    @Published var careTasks: [CareTask] = []
    @Published var hasUrgentTask = false          // 是否有 3 天内临期任务（控制铃铛显示）

    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createCareTable()
        loadCareTasks()
    }

    // ============================================================
    // 数据库连接
    // ============================================================
    private func openDatabase() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("DesktopCat")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbPath = dir.appendingPathComponent("reminders.db").path
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("打开数据库失败")
        }
    }

    // ============================================================
    // 普通提醒（原有功能）
    // ============================================================
    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS reminders (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            title    TEXT NOT NULL,
            due_date REAL NOT NULL,
            is_done  INTEGER DEFAULT 0,
            notified INTEGER DEFAULT 0
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    func loadAll() {
        var result: [Reminder] = []
        let sql = "SELECT id, title, due_date, is_done, notified FROM reminders ORDER BY due_date;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let reminder = Reminder(
                    id: sqlite3_column_int64(stmt, 0),
                    title: String(cString: sqlite3_column_text(stmt, 1)),
                    dueDate: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                    isDone: sqlite3_column_int(stmt, 3) == 1,
                    notified: sqlite3_column_int(stmt, 4) == 1
                )
                result.append(reminder)
            }
        }
        sqlite3_finalize(stmt)
        reminders = result
    }

    func add(title: String, dueDate: Date) {
        let sql = "INSERT INTO reminders (title, due_date) VALUES (?, ?);"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (title as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, dueDate.timeIntervalSince1970)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadAll()
    }

    func toggleDone(_ reminder: Reminder) {
        let sql = "UPDATE reminders SET is_done = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, reminder.isDone ? 0 : 1)
            sqlite3_bind_int64(stmt, 2, reminder.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadAll()
    }

    func delete(_ reminder: Reminder) {
        let sql = "DELETE FROM reminders WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, reminder.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadAll()
    }

    func checkDueReminders() {
        loadAll()
        let now = Date()
        for r in reminders where r.dueDate <= now && !r.isDone && !r.notified {
            notify(title: "🐱 小猫提醒", message: "「\(r.title)」到时间啦！")
            markNotified(r)
        }
    }

    private func markNotified(_ reminder: Reminder) {
        let sql = "UPDATE reminders SET notified = 1 WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, reminder.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadAll()
    }

    // ============================================================
    // 养护周期任务
    // ============================================================
    private func createCareTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS care_tasks (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            type                TEXT NOT NULL,
            interval            INTEGER NOT NULL,
            next_due            REAL NOT NULL,
            last_notified_date  TEXT DEFAULT ''
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
        // 兼容旧表：如果旧表有 notified 列但没有 last_notified_date 列，加上
        let alter = "ALTER TABLE care_tasks ADD COLUMN last_notified_date TEXT DEFAULT '';"
        sqlite3_exec(db, alter, nil, nil, nil)  // 已存在会报错但无妨
        setupDefaultCareTasks()
    }

    // 首次运行时插入默认任务（表为空时）
    private func setupDefaultCareTasks() {
        var stmt: OpaquePointer?
        let countSql = "SELECT COUNT(*) FROM care_tasks;"
        if sqlite3_prepare_v2(db, countSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_step(stmt)
            let count = sqlite3_column_int(stmt, 0)
            sqlite3_finalize(stmt)
            if count > 0 { return }  // 已经有数据了
        } else {
            sqlite3_finalize(stmt)
            return
        }

        // 默认任务：下次到期设为"今天"，等用户设置首次日期
        let defaults: [(String, Int)] = [
            ("剪指甲", 15),
            ("掏耳朵", 15),
            ("外驱", 30),
            ("内驱", 90),
            ("换猫砂", 60),
            ("深度梳毛", 7)
        ]

        let now = Date().timeIntervalSince1970
        let insertSql = "INSERT INTO care_tasks (type, interval, next_due) VALUES (?, ?, ?);"
        for (type, interval) in defaults {
            var insertStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSql, -1, &insertStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(insertStmt, 1, (type as NSString).utf8String, -1, nil)
                sqlite3_bind_int(insertStmt, 2, Int32(interval))
                sqlite3_bind_double(insertStmt, 3, now)
                sqlite3_step(insertStmt)
            }
            sqlite3_finalize(insertStmt)
        }
    }

    func loadCareTasks() {
        var result: [CareTask] = []
        let sql = "SELECT id, type, interval, next_due, last_notified_date FROM care_tasks ORDER BY next_due;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let lastNotified: String
                if let ptr = sqlite3_column_text(stmt, 4) {
                    lastNotified = String(cString: ptr)
                } else {
                    lastNotified = ""
                }
                let task = CareTask(
                    id: sqlite3_column_int64(stmt, 0),
                    type: String(cString: sqlite3_column_text(stmt, 1)),
                    interval: Int(sqlite3_column_int(stmt, 2)),
                    nextDue: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                    lastNotifiedDate: lastNotified
                )
                result.append(task)
            }
        }
        sqlite3_finalize(stmt)
        careTasks = result

        // 更新铃铛状态：是否有 3 天内临期或已逾期的任务
        let threeDaysLater = Date().addingTimeInterval(3 * 86400)
        hasUrgentTask = careTasks.contains { $0.nextDue <= threeDaysLater }
    }

    // 标记完成：从现在起算下一次到期时间，同时清除提醒状态
    func completeTask(_ task: CareTask) {
        let nextDue = Date().addingTimeInterval(Double(task.interval) * 86400)
        let sql = "UPDATE care_tasks SET next_due = ?, last_notified_date = '' WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, nextDue.timeIntervalSince1970)
            sqlite3_bind_int64(stmt, 2, task.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadCareTasks()
    }

    // 设置首次完成日期：从那天起算下一次
    func setFirstDate(_ task: CareTask, date: Date) {
        let nextDue = date.addingTimeInterval(Double(task.interval) * 86400)
        let sql = "UPDATE care_tasks SET next_due = ?, last_notified_date = '' WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, nextDue.timeIntervalSince1970)
            sqlite3_bind_int64(stmt, 2, task.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadCareTasks()
    }

    // 检查养护任务：到期前 3 天开始每天弹一次系统通知
    func checkCareTasks() {
        loadCareTasks()
        let now = Date()
        let today = todayString()
        let threeDaysLater = now.addingTimeInterval(3 * 86400)

        for task in careTasks {
            let shouldRemind = task.nextDue <= threeDaysLater && task.lastNotifiedDate != today
            if shouldRemind {
                let daysLeft = Calendar.current.dateComponents([.day], from: now, to: task.nextDue).day ?? 0
                let message: String
                if daysLeft <= 0 {
                    message = "该\(task.type)啦！"
                } else {
                    message = "还有\(daysLeft)天该\(task.type)啦"
                }
                notify(title: "🐱 养护提醒", message: message)
                markCareNotifiedToday(task)
                break  // 一次只弹一个通知
            }
        }
    }

    private func todayString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func markCareNotifiedToday(_ task: CareTask) {
        let today = todayString()
        let sql = "UPDATE care_tasks SET last_notified_date = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (today as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, task.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadCareTasks()
    }

    // 弹系统通知
    private func notify(title: String, message: String) {
        let script = "display notification \"\(message)\" with title \"\(title)\" sound name \"Purr\""
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        try? task.run()
    }
}
