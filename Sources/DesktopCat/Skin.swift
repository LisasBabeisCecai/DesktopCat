// ============================================================
// Skin.swift —— 小猫的"皮肤"（AI 生成的图片帧 或 视频）
//
// 工作方式：程序启动时去固定文件夹找素材
//   ~/Library/Application Support/DesktopCat/skin/
//
// 【视频皮肤】（优先级最高）认这些文件名，必须是带透明通道的 .mov
//   idle.mov   坐着/站着的日常视频（循环播放）
//   sit.mov    坐下视频（和 idle 随机切换）
//   pet.mov    被摸时的反应视频（可选，点击小猫时播放一遍）
//   walk.mov   走路动作视频（可选，散步时循环播放）
//
// 【图片皮肤】（没有视频时用）透明背景 PNG：
//   idle.png / blink.png / pet.png / walk1.png ~ walk8.png
//
// 都没有 → 用代码画的卡通猫。
// ============================================================
import AppKit
import SwiftUI
import AVFoundation

class Skin: ObservableObject {
    static let shared = Skin()   // 全局共用一份

    // ---- 图片皮肤 ----
    @Published var idle: NSImage?
    @Published var blink: NSImage?
    @Published var pet: NSImage?
    @Published var walk: [NSImage] = []

    // ---- 视频皮肤（使用 AlphaVideoPlayer 逐帧渲染）----
    @Published var idleVideo: AlphaVideoPlayer?
    @Published var sitVideo: AlphaVideoPlayer?
    @Published var petVideo: AlphaVideoPlayer?
    @Published var walkVideo: AlphaVideoPlayer?

    // 有 idle.png 就算"有图片皮肤"；有 idle.mov 就算"有视频皮肤"
    var hasSkin: Bool { idle != nil }
    var hasVideoSkin: Bool { idleVideo != nil }

    // 皮肤文件夹路径（不存在会自动创建，方便你直接把素材拖进去）
    static var folder: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("DesktopCat/skin")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() { load() }

    // 重新读一遍文件夹（换素材后从菜单栏点"重新加载皮肤"即可，不用重启）
    func load() {
        let dir = Skin.folder

        // 视频（用 AlphaVideoPlayer 逐帧取带 alpha 的帧）
        idleVideo = AlphaVideoPlayer(url: dir.appendingPathComponent("idle.mov"))
        sitVideo  = AlphaVideoPlayer(url: dir.appendingPathComponent("sit.mov"))
        petVideo  = AlphaVideoPlayer(url: dir.appendingPathComponent("pet.mov"))
        walkVideo = AlphaVideoPlayer(url: dir.appendingPathComponent("walk.mov"))

        // 图片
        idle  = NSImage(contentsOf: dir.appendingPathComponent("idle.png"))
        blink = NSImage(contentsOf: dir.appendingPathComponent("blink.png"))
        pet   = NSImage(contentsOf: dir.appendingPathComponent("pet.png"))

        walk = []
        for i in 1...8 {
            if let img = NSImage(contentsOf: dir.appendingPathComponent("walk\(i).png")) {
                walk.append(img)
            }
        }
    }
}
