// ============================================================
// main.swift —— 程序的入口，运行程序时最先执行的文件
// ============================================================
import AppKit

// NSApplication 代表"这个 App 本身"，每个 mac 程序都有且只有一个
let app = NSApplication.shared

// AppDelegate 是我们自己写的"总管家"类（见 AppDelegate.swift），
// 系统会在 App 启动、退出等时机通知它
let delegate = AppDelegate()
app.delegate = delegate

// .accessory 表示：不在 Dock（程序坞）里显示图标，只在顶部菜单栏出现。
// 桌面宠物类的 App 一般都这样，不占地方。
app.setActivationPolicy(.accessory)

// 启动主循环（程序从这里开始一直运行，直到退出）
app.run()
