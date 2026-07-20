// ============================================================
// CatView.swift —— 小猫本体（SwiftUI 画的）
// 功能 2：眼珠跟着鼠标转    功能 3：点击小猫互动
// ============================================================
import SwiftUI
import AppKit
import AVFoundation
import CoreVideo

// ------------------------------------------------------------
// EyeTracker：负责追踪鼠标，算出瞳孔应该偏移多少
// ------------------------------------------------------------
class EyeTracker: ObservableObject {
    @Published var pupilOffset: CGSize = .zero

    private var timer: Timer?
    private let maxOffset: CGFloat = 6

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    private func update() {
        let mouse = NSEvent.mouseLocation
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.level == .floating }) else { return }
        let catCenter = NSPoint(x: window.frame.midX, y: window.frame.midY + 30)

        let dx = mouse.x - catCenter.x
        let dy = mouse.y - catCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 1 else { return }

        let scale = min(distance / 100, 1.0) * maxOffset
        let offset = CGSize(width: dx / distance * scale,
                            height: -dy / distance * scale)

        DispatchQueue.main.async {
            self.pupilOffset = offset
        }
    }
}

// ------------------------------------------------------------
// AlphaVideoPlayer：用 AVAssetReader 按需逐帧解码带 alpha 的视频
// 比 AVPlayer 轻量得多：不预加载整个视频，只在需要时解码一帧
// ------------------------------------------------------------
class AlphaVideoPlayer: ObservableObject {
    @Published var currentFrame: NSImage?

    let duration: Double
    let frameCount: Int
    private let url: URL
    private let fps: Double
    private var currentFrameIndex: Int = 0
    private var frameTimer: Timer?
    private var assetReader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var isPlaying = false

    init?(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        self.url = url
        let asset = AVAsset(url: url)
        self.duration = CMTimeGetSeconds(asset.duration)
        // 获取帧率
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        self.fps = Double(track.nominalFrameRate)
        self.frameCount = Int(self.duration * self.fps)
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        setupReader()
        startFrameTimer()
    }

    func pause() {
        isPlaying = false
        frameTimer?.invalidate()
        frameTimer = nil
    }

    func restart() {
        pause()
        currentFrameIndex = 0
        assetReader?.cancelReading()
        assetReader = nil
        play()
    }

    private func setupReader() {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else { return }

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)

        do {
            let reader = try AVAssetReader(asset: asset)
            reader.add(output)
            reader.startReading()
            self.assetReader = reader
            self.trackOutput = output
        } catch {
            // 读取失败
        }
    }

    private func startFrameTimer() {
        let interval = 1.0 / fps
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.readNextFrame()
        }
    }

    private func readNextFrame() {
        guard isPlaying else { return }

        // 如果 reader 结束了（视频播完），重新开始（循环）
        if assetReader?.status != .reading {
            assetReader?.cancelReading()
            assetReader = nil
            currentFrameIndex = 0
            setupReader()
            guard assetReader?.status == .reading else { return }
        }

        guard let output = trackOutput,
              let sampleBuffer = output.copyNextSampleBuffer(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            // 没有更多帧了，循环
            assetReader?.cancelReading()
            assetReader = nil
            currentFrameIndex = 0
            setupReader()
            return
        }

        currentFrameIndex += 1

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: w, height: h)) else { return }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: w, height: h))
        DispatchQueue.main.async {
            self.currentFrame = nsImage
        }
    }

    deinit {
        frameTimer?.invalidate()
        assetReader?.cancelReading()
    }
}

// ------------------------------------------------------------
// 小猫整体
// ------------------------------------------------------------
struct CatView: View {
    @StateObject private var tracker = EyeTracker()
    @ObservedObject var motion: CatMotion
    @ObservedObject var skin = Skin.shared
    @ObservedObject var store = ReminderStore.shared

    @State private var isBlinking = false
    @State private var showMeow = false
    @State private var bounce = false
    @State private var walkPhase = false
    @State private var isPetting = false
    @State private var isSitting = false
    @State private var alertText: String? = nil

    @State private var bellSwing = false      // 铃铛摇晃动画

    var body: some View {
        // 小猫本体
        ZStack {
            Group {
                if skin.hasVideoSkin {
                    videoBody
                } else {
                    cartoonBody
                }
            }
            .scaleEffect(bounce ? 1.1 : 1.0)
            .rotationEffect(.degrees(walkRotation))
            .animation(.easeInOut(duration: 0.25), value: walkPhase)

            // 🔔 小铃铛提醒图标（3天内有临期任务时显示）
            if store.hasUrgentTask {
                Text("🔔")
                    .font(.system(size: 24))
                    .rotationEffect(.degrees(bellSwing ? 15 : -15))
                    .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: bellSwing)
                    .offset(x: 85, y: -75)
                    .onAppear { bellSwing = true }
            }
        }
        .frame(width: 220, height: 220)
        .contentShape(Rectangle())
        .onTapGesture { petCat() }
        .clipped()
        .onAppear {
            startBlinkLoop()
            startVideoPlayback()
        }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            if motion.isWalking { walkPhase.toggle() }
        }
    }

    // 视频版：根据 motion.state 选择显示哪个视频帧
    var videoBody: some View {
        let frame: NSImage? = {
            switch motion.state {
            case .pet:  return skin.petVideo?.currentFrame
            case .walk: return skin.walkVideo?.currentFrame
            case .sit:  return skin.sitVideo?.currentFrame
            case .idle: return skin.idleVideo?.currentFrame
            }
        }()

        return Group {
            if let frame = frame {
                Image(nsImage: frame)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .frame(width: 200, height: 200)
        .clipped()
        .scaleEffect(x: motion.isWalking && motion.facingRight ? -1 : 1)
    }

    var walkRotation: Double {
        guard motion.isWalking else { return 0 }
        let lean: Double = motion.facingRight ? 3 : -3
        let sway: Double = walkPhase ? 2 : -2
        return lean + sway
    }

    // 点击小猫
    func petCat() {
        // walk/sit 期间不可打断
        guard motion.state == .idle else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
            bounce = true
        }

        motion.startPet()
        skin.petVideo?.restart()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring()) { bounce = false }
        }
    }

    func startBlinkLoop() {
        let delay = Double.random(in: 3...6)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBlinking = false
                startBlinkLoop()
            }
        }
    }

    func startVideoPlayback() {
        guard skin.hasVideoSkin else { return }
        // 启动所有视频播放（它们各自循环，View 只选择显示哪个的帧）
        skin.idleVideo?.play()
        skin.sitVideo?.play()
        skin.walkVideo?.play()
        skin.petVideo?.play()

        // 把视频时长告诉 motion
        motion.walkDuration = skin.walkVideo?.duration ?? 5.0
        motion.sitDuration = skin.sitVideo?.duration ?? 1.5
        motion.petDuration = skin.petVideo?.duration ?? 1.5
    }

    var cartoonBody: some View {
        Text("🐱").font(.system(size: 120))
    }
}
