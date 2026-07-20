// ============================================================
// AppDelegate.swift —— App 的"总管家"
// 负责：1) 创建小猫的透明窗口  2) 菜单栏图标（控制小猫出现/消失）
//       3) 打开提醒管理窗口    4) 定时检查有没有到期的提醒
// ============================================================
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    var catWindow: NSWindow!            // 小猫住的窗口
    var statusItem: NSStatusItem!       // 顶部菜单栏的小图标
    var careWindow: NSWindow?           // 养护提醒窗口
    var reminderTimer: Timer?           // 定时器：每分钟检查一次提醒
    let motion = CatMotion()            // 小猫的"腿"：控制它在屏幕里散步

    // App 启动完成后，系统会自动调用这个方法
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupCatWindow()
        setupStatusBar()
        startReminderCheck()
    }

    // ------------------------------------------------------------
    // 1. 小猫的窗口：透明、无边框、置顶、可拖动
    // ------------------------------------------------------------
    func setupCatWindow() {
        let size = NSSize(width: 220, height: 220)

        // 把小猫放在屏幕右下角（留 40 像素边距）
        let screen = NSScreen.main!.visibleFrame
        let origin = NSPoint(x: screen.maxX - size.width - 40,
                             y: screen.minY + 40)

        catWindow = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],   // 无边框：没有标题栏和关闭按钮
            backing: .buffered,
            defer: false
        )

        catWindow.isOpaque = false                  // 允许透明
        catWindow.backgroundColor = .clear          // 背景完全透明
        catWindow.level = .floating                 // 永远浮在其他窗口上面
        catWindow.hasShadow = false                 // 不要系统阴影（猫身外是透明的）
        catWindow.isMovableByWindowBackground = true // 按住猫身任意处可拖动

        // 让窗口在所有"桌面空间"（Space）都出现
        catWindow.collectionBehavior = [.canJoinAllSpaces]

        // 把 SwiftUI 写的小猫视图装进窗口，并把"腿"(motion)传给它，
        // 这样走路时小猫能播放颠簸/转身动画
        let hostingView = NSHostingView(rootView: CatView(motion: motion))
        hostingView.layer?.backgroundColor = .clear
        catWindow.contentView = hostingView

        catWindow.makeKeyAndOrderFront(nil)  // 显示出来

        motion.start(window: catWindow)      // 开始散步循环
    }

    // ------------------------------------------------------------
    // 2. 菜单栏图标 + 菜单
    // ------------------------------------------------------------
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // 用系统自带的猫爪印图标；找不到就显示文字
        if let icon = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "小猫") {
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "🐱"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏小猫", action: #selector(toggleCat), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "养护提醒…", action: #selector(openCare), keyEquivalent: "c"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "打开皮肤文件夹", action: #selector(openSkinFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新加载皮肤", action: #selector(reloadSkin), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // 在访达中打开皮肤文件夹，把 AI 生成的 PNG 直接拖进去
    @objc func openSkinFolder() {
        NSWorkspace.shared.open(Skin.folder)
    }

    // 放好图片后点这个，小猫立刻换装（不用重启程序）
    @objc func reloadSkin() {
        Skin.shared.load()
    }

    // 功能 1：控制小猫出现和消失
    @objc func toggleCat() {
        if catWindow.isVisible {
            catWindow.orderOut(nil)              // 隐藏
        } else {
            catWindow.makeKeyAndOrderFront(nil)  // 显示
        }
    }

    // ------------------------------------------------------------
    // 3. 养护提醒窗口
    // ------------------------------------------------------------
    @objc func openCare() {
        if careWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 450),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "🐾 养护周期提醒"
            window.center()
            window.contentView = NSHostingView(rootView: CareView())
            window.isReleasedWhenClosed = false
            careWindow = window
        }
        careWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // ------------------------------------------------------------
    // 4. 每 60 秒检查一次有没有到期的养护提醒
    // ------------------------------------------------------------
    func startReminderCheck() {
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            ReminderStore.shared.checkCareTasks()
        }
        // 启动时立刻检查一次
        ReminderStore.shared.checkCareTasks()
    }
}
