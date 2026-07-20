# DesktopCat 🐱 桌面小猫

> 一只住在你 Mac 桌面上的猫咪。带透明通道视频皮肤，有 idle / walk / sit / pet 四种动画状态，还能提醒你按时给猫做养护。

**[English](#desktopcat--desktop-cat-for-macos) | 中文**

---

## 效果

小猫悬浮在所有窗口上方，背景完全透明，可拖到屏幕任意位置。30 秒无互动后自动播放走路动画，点击会播放被摸动画。菜单栏有猫爪图标，管理显示/隐藏和养护提醒。

---

## 功能

- 带 Alpha 通道的视频皮肤（ProRes 4444 MOV），四种状态动画
- 点击互动：播放 pet 动画
- 30 秒无互动自动触发 walk → sit 动画
- 养护周期提醒：剪指甲、掏耳朵、内外驱、换猫砂、梳毛，到期前 3 天铃铛提醒 + 系统通知
- 菜单栏驻留，不占 Dock
- 可拖动，固定在你喜欢的位置

---

## 系统要求

- macOS 13.0 Ventura 及以上
- Apple Silicon 或 Intel Mac
- Xcode Command Line Tools

---

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/LisasBabeisCecai/DesktopCat.git
cd DesktopCat
```

### 2. 准备皮肤素材

程序需要 4 个带透明通道的 MOV 视频文件，放到指定目录：

```
~/Library/Application Support/DesktopCat/skin/
├── idle.mov    # 待机循环动画（必须）
├── walk.mov    # 走路动画（必须）
├── sit.mov     # 坐下动画（必须）
└── pet.mov     # 被摸动画（必须）
```

**方法 A：用仓库自带的占位素材快速体验**

```bash
mkdir -p ~/Library/Application\ Support/DesktopCat/skin
cp skin_placeholder/*.mov ~/Library/Application\ Support/DesktopCat/skin/
```

占位素材是缩小版（200×200），动画内容与正式版相同，可以正常运行，但画质较低。

**方法 B：制作你自己的皮肤（推荐）**

见下方「制作素材」章节。

### 3. 本地测试

```bash
swift run
```

第一次编译约需 30 秒，之后小猫出现在屏幕右下角，顶部菜单栏出现猫爪图标 🐾。

### 4. 打包成 .app

```bash
# 编译 Release 版本
swift build -c release

# 创建 .app 包结构
APP=~/Applications/DesktopCat.app
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# 复制可执行文件
cp .build/release/DesktopCat "$APP/Contents/MacOS/DesktopCat"

# 写入 Info.plist
cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DesktopCat</string>
    <key>CFBundleDisplayName</key><string>桌面小猫</string>
    <key>CFBundleIdentifier</key><string>com.yourname.desktopcat</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleExecutable</key><string>DesktopCat</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# 启动
open ~/Applications/DesktopCat.app
```

### 5. 后续更新（每次改完代码都要走这四步）

```bash
cd DesktopCat
swift build -c release
killall DesktopCat 2>/dev/null
cp .build/release/DesktopCat ~/Applications/DesktopCat.app/Contents/MacOS/
open ~/Applications/DesktopCat.app
```

> 注意：只跑 `swift build`（debug）不会更新 .app 里的可执行文件，改动不会生效。

---

## 制作素材

皮肤的核心要求：**带 Alpha 通道的 ProRes 4444 MOV 视频，背景完全透明。**

### 视频规格

| 属性 | 要求 |
|------|------|
| 格式 | QuickTime .mov |
| 编码 | Apple ProRes 4444 XQ |
| 像素格式 | yuva444p12le（含 Alpha）|
| 分辨率 | 1080×1080（程序内缩放显示）|
| 帧率 | 30fps |
| 背景 | 完全透明（alpha=0）|

### 推荐流程

**用 AI 生图工具生成带透明背景的 PNG 序列帧，再用 ffmpeg 合成视频。**

1. **用 AI 生成角色帧**（Midjourney、Stable Diffusion 等）
   - 提示词示例：`cute cat sitting, transparent background, white background, cartoon style, full body`
   - 导出为 PNG，确保背景已被移除（透明或纯白均可，纯白需后处理去背）

2. **去除白色背景**（如果 AI 输出是白底）
   ```bash
   # 用 ffmpeg 将白色替换为透明
   ffmpeg -i input.png -vf "colorkey=white:0.1:0.1" output.png
   ```

3. **将 PNG 序列合成为 ProRes 4444 视频**
   ```bash
   ffmpeg -framerate 30 -i frame_%04d.png \
     -c:v prores_ks -profile:v 4 \
     -pix_fmt yuva444p10le \
     output.mov
   ```

4. **验证格式**
   ```bash
   ffprobe -v error -select_streams v:0 \
     -show_entries stream=codec_name,pix_fmt \
     output.mov
   # 正确输出：codec_name=prores  pix_fmt=yuva444p10le
   ```

5. 将生成的文件重命名为 `idle.mov` / `walk.mov` / `sit.mov` / `pet.mov` 放到皮肤目录。

### 下载本项目使用的原始素材

本项目使用的高清素材（1080×1080 ProRes 4444，约 1.3GB）已单独上传网盘：

> 🔗 **素材网盘链接**：（cecilia 填入）

---

## 项目结构

```
DesktopCat/
├── Package.swift
├── Sources/DesktopCat/
│   ├── main.swift             # 程序入口
│   ├── AppDelegate.swift      # 窗口管理、菜单栏、定时检查
│   ├── CatView.swift          # 小猫视图 + 视频帧渲染
│   ├── CatMotion.swift        # 状态机（idle/walk/sit/pet）
│   ├── Skin.swift             # 皮肤加载
│   ├── ReminderStore.swift    # SQLite 养护数据层
│   ├── CareView.swift         # 养护提醒管理界面
│   └── RemindersView.swift    # 旧版通用提醒（已停用）
├── skin_placeholder/          # 占位示例素材（低分辨率，可直接运行）
│   ├── idle.mov
│   ├── walk.mov
│   ├── sit.mov
│   └── pet.mov
└── docs/
    ├── requirements.md
    ├── development.md
    └── deployment.md
```

---

## 数据存储位置

| 数据 | 路径 |
|------|------|
| 皮肤视频 | `~/Library/Application Support/DesktopCat/skin/` |
| 养护数据库 | `~/Library/Application Support/DesktopCat/reminders.db` |
| App 本体 | `~/Applications/DesktopCat.app` |

---

## 故障排除

| 问题 | 解决 |
|------|------|
| 小猫不显示 | 确认 `skin/idle.mov` 文件存在 |
| 显示黑色背景 | 视频没有 Alpha 通道，用 ffprobe 确认 pix_fmt 含 `a` |
| 改了代码没生效 | 必须走完更新四步，尤其是 `cp` 覆盖 .app 可执行文件 |
| 启动很慢 | 用 `swift build -c release` 编译 Release 版 |

---

# DesktopCat — Desktop Cat for macOS

> A cat that lives on your Mac desktop. Transparent video skin with idle / walk / sit / pet animations, plus a care reminder for grooming schedules.

**中文 | [English](#desktopcat--desktop-cat-for-macos)**

---

## Features

- Transparent ProRes 4444 video skin with four animation states
- Click to trigger pet animation
- Auto walk → sit animation after 30 seconds of inactivity
- Care reminders: nail trim, ear cleaning, deworming, litter change, grooming — bell icon + system notification 3 days before due
- Menu bar icon, no Dock entry
- Draggable, stays where you put it

---

## Requirements

- macOS 13.0 Ventura or later
- Apple Silicon or Intel Mac
- Xcode Command Line Tools

---

## Quick Start

### 1. Clone

```bash
git clone https://github.com/LisasBabeisCecai/DesktopCat.git
cd DesktopCat
```

### 2. Prepare skin assets

Place 4 transparent MOV files into:

```
~/Library/Application Support/DesktopCat/skin/
├── idle.mov
├── walk.mov
├── sit.mov
└── pet.mov
```

**Option A: Use the placeholder assets included in this repo**

```bash
mkdir -p ~/Library/Application\ Support/DesktopCat/skin
cp skin_placeholder/*.mov ~/Library/Application\ Support/DesktopCat/skin/
```

**Option B: Make your own skins** — see the "Making Assets" section below.

### 3. Run locally

```bash
swift run
```

The cat appears in the bottom-right corner. A paw icon 🐾 appears in the menu bar.

### 4. Package as .app

```bash
swift build -c release

APP=~/Applications/DesktopCat.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/DesktopCat "$APP/Contents/MacOS/DesktopCat"
# write Info.plist — see the Chinese section above for the full template
open ~/Applications/DesktopCat.app
```

### 5. After each code change

```bash
swift build -c release
killall DesktopCat 2>/dev/null
cp .build/release/DesktopCat ~/Applications/DesktopCat.app/Contents/MacOS/
open ~/Applications/DesktopCat.app
```

> Important: `swift build` (debug) does NOT update the .app binary. Always run the full four steps.

---

## Making Assets

The skin requires **ProRes 4444 MOV videos with an alpha channel** (transparent background).

| Property | Requirement |
|----------|-------------|
| Format | QuickTime .mov |
| Codec | Apple ProRes 4444 XQ |
| Pixel format | yuva444p10le (with alpha) |
| Resolution | 1080×1080 |
| Frame rate | 30 fps |
| Background | Fully transparent (alpha=0) |

**Recommended workflow:**

1. Generate character frames with an AI image tool (Midjourney, Stable Diffusion, etc.) — transparent or white background
2. If white background, remove it: `ffmpeg -i input.png -vf "colorkey=white:0.1:0.1" output.png`
3. Assemble PNG sequence into ProRes video:
   ```bash
   ffmpeg -framerate 30 -i frame_%04d.png \
     -c:v prores_ks -profile:v 4 \
     -pix_fmt yuva444p10le \
     output.mov
   ```
4. Verify: `ffprobe` should show `codec_name=prores` and `pix_fmt=yuva444p10le`
5. Rename to `idle.mov` / `walk.mov` / `sit.mov` / `pet.mov` and copy to the skin directory

**Download the original HD assets used in this project:**

> 🔗 **Asset download link**: (cecilia to fill in)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Cat not visible | Check that `skin/idle.mov` exists |
| Black background | Video has no alpha channel — verify with ffprobe |
| Code change has no effect | Must run all four update steps, especially the `cp` to overwrite the .app binary |
| Slow startup | Use `swift build -c release` |
