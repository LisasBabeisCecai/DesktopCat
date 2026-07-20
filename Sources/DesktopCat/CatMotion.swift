// ============================================================
// CatMotion.swift —— 小猫的状态机
//
// 状态流转：
//   idle（默认）──30秒无互动──▶ walk（播完一遍）──▶ sit（播完一遍）──▶ idle
//   idle ──点击──▶ pet（播完一遍）──▶ idle
//
// 约束：
//   - walk 和 sit 必须完整播放，不可打断
//   - 窗口不发生任何位移，小猫原地做动作
//   - 点击/拖动重置 30 秒计时器
// ============================================================
import AppKit
import SwiftUI

enum CatState: Equatable {
    case idle
    case walk
    case sit
    case pet
}

class CatMotion: ObservableObject {
    @Published var state: CatState = .idle
    @Published var facingRight = true

    weak var window: NSWindow?
    private var idleTimer: Timer?       // 30 秒无互动计时器

    // 外部设置视频时长
    var walkDuration: Double = 5.0
    var sitDuration: Double = 1.5
    var petDuration: Double = 1.5

    var isWalking: Bool { state == .walk }

    func start(window: NSWindow) {
        self.window = window
        resetIdleTimer()
    }

    // ---- 重置 30 秒无互动计时器 ----
    func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.beginWalk()
        }
    }

    // ---- 点击互动 → pet ----
    func startPet() {
        // walk/sit 期间不可打断
        guard state == .idle else { return }
        idleTimer?.invalidate()
        state = .pet
        DispatchQueue.main.asyncAfter(deadline: .now() + petDuration) { [weak self] in
            self?.state = .idle
            self?.resetIdleTimer()
        }
    }

    // ---- 开始走路 ----
    private func beginWalk() {
        guard state == .idle else { resetIdleTimer(); return }
        guard let window, window.isVisible else { resetIdleTimer(); return }

        // 随机朝向，但不移动窗口
        facingRight = Bool.random()

        state = .walk

        // walk 视频播完后，进入 sit
        DispatchQueue.main.asyncAfter(deadline: .now() + walkDuration) { [weak self] in
            self?.stopWalk()
        }
    }

    private func stopWalk() {
        beginSit()
    }

    // ---- sit：播完一遍后回 idle ----
    private func beginSit() {
        state = .sit
        DispatchQueue.main.asyncAfter(deadline: .now() + sitDuration) { [weak self] in
            self?.state = .idle
            self?.resetIdleTimer()
        }
    }
}
