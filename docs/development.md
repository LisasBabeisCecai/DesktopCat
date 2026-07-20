# 开发文档 — DesktopCat

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.9 |
| UI 框架 | SwiftUI + AppKit (NSWindow) |
| 视频解码 | AVFoundation (AVAssetReader) |
| 图像渲染 | CoreImage (CIContext GPU 加速) |
| 数据库 | SQLite3 (系统自带 C API) |
| 构建工具 | Swift Package Manager |
| 最低系统 | macOS 13.0 |

## 架构概览

```
┌─────────────┐     ┌──────────────┐     ┌───────────────┐
│ main.swift  │────▶│ AppDelegate  │────▶│  CatMotion    │
│ (入口)      │     │ (窗口+菜单)   │     │  (状态机)     │
└─────────────┘     └──────┬───────┘     └───────┬───────┘
                           │                     │
                    ┌──────▼───────┐     ┌───────▼───────┐
                    │   CatView    │◀────│AlphaVideoPlayer│
                    │ (SwiftUI视图) │     │ (逐帧解码)     │
                    └──────┬───────┘     └───────────────┘
                           │
                    ┌──────▼───────┐     ┌───────────────┐
                    │    Skin      │     │ ReminderStore  │
                    │ (皮肤加载)    │     │ (SQLite 数据)  │
                    └──────────────┘     └───────┬───────┘
                                                 │
                                         ┌───────▼───────┐
                                         │   CareView    │
                                         │ (养护提醒界面)  │
                                         └───────────────┘
```

## 核心模块说明

### main.swift
程序入口。创建 NSApplication，设置 delegate，设为 accessory 模式（不显示 Dock 图标）。

### AppDelegate.swift
职责：
- 创建透明无边框窗口（NSWindow, borderless, isOpaque=false）
- 初始化菜单栏图标和下拉菜单
- 启动定时器每 60 秒检查养护任务到期
- 管理养护提醒窗口的创建和显示

### CatMotion.swift
状态机。

状态枚举：`idle | walk | sit | pet`

状态流转：
```
idle ──(30s无互动)──▶ walk ──(视频播完)──▶ sit ──(视频播完)──▶ idle
idle ──(点击)──▶ pet ──(视频播完)──▶ idle
```

walk 状态只随机翻转朝向（`facingRight`），窗口位置不发生任何位移。

### CatView.swift
包含两个核心类：

**AlphaVideoPlayer**
- 用 AVAssetReader + AVAssetReaderTrackOutput 逐帧读取
- 输出格式：kCVPixelFormatType_32BGRA（保留 Alpha）
- CIContext (GPU) 将 pixelBuffer → CGImage → NSImage
- 30fps Timer 驱动，视频结束自动循环（重建 reader）
- 按需启动：play() 才开始解码，不预加载

**CatView (SwiftUI View)**
- 根据 motion.state 选择显示哪个视频的 currentFrame
- walk 状态：镜像翻转（facingRight）+ 左右摇摆动画
- 点击触发 petCat() → 通知 CatMotion 进入 pet 状态
- 监听 store.hasUrgentTask 显示/隐藏铃铛

### Skin.swift
皮肤加载器。从 `~/Library/Application Support/DesktopCat/skin/` 读取：
- 视频皮肤：idle.mov / walk.mov / sit.mov / pet.mov
- 图片皮肤：idle.png / walk1~8.png / blink.png / pet.png（备用）

### ReminderStore.swift
SQLite 数据层。

表结构 `care_tasks`：
```sql
id                INTEGER PRIMARY KEY
type              TEXT        -- 任务名称
interval          INTEGER     -- 周期天数
next_due          REAL        -- 下次到期时间戳
last_notified_date TEXT       -- 上次通知日期 "yyyy-MM-dd"
```

核心方法：
- `completeTask()` — next_due = now + interval days
- `setFirstDate()` — next_due = date + interval days
- `checkCareTasks()` — 检查 3 天内到期且今天未通知的任务

### CareView.swift
SwiftUI 界面，展示 6 个任务卡片。支持"完成"和"设置日期"操作。

颜色规则：
- 逾期：红色背景 + 红色边框
- 3 天内临期：橙色背景 + 橙色边框
- 正常：灰色

## 关键技术决策

### 为什么用 AVAssetReader 而不是 AVPlayer？

AVPlayerLayer 在 macOS 上不支持 Alpha 通道渲染（透明区域显示为黑色）。AVPlayer + AVPlayerItemVideoOutput 方案虽能取帧，但 AVPlayerLooper 创建多个 playerItem 导致内存暴涨（4 个 500MB+ 视频同时加载）。

AVAssetReader 按需解码，一次只读一帧，内存占用极低。

### 为什么用 CIContext 而不是直接创建 NSImage？

CIContext 支持 GPU 加速渲染，从 CVPixelBuffer 生成 CGImage 的速度远快于 CPU 路径。复用同一个 CIContext 实例避免重复初始化开销。

### 为什么视频素材这么大？

ProRes 4444 XQ 是无损格式，1080p 10 秒 ≈ 500-700MB。程序实际只显示 200×200，但保留高分辨率源文件方便未来放大窗口。如果要减小体积，可以用 ffmpeg 缩放到 400×400 再存。

## 开发环境

```bash
# 编译（Debug）
swift build

# 编译（Release，优化性能）
swift build -c release

# 运行
swift run

# 清理
swift package clean
```

## 添加新状态/视频

1. 在 CatMotion.swift 的 `CatState` 枚举中加新状态
2. 在 Skin.swift 中加对应的 `AlphaVideoPlayer` 属性和加载逻辑
3. 在 CatView.swift 的 `videoBody` 中加 case 分支
4. 把视频放到 `~/Library/Application Support/DesktopCat/skin/`
