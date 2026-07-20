# 部署文档 — DesktopCat

## 从源码构建 .app

### 前置条件

- macOS 13.0+
- Xcode Command Line Tools（`xcode-select --install`）
- 视频皮肤文件已放置到位

### 构建步骤

```bash
# 1. 编译 Release 版本
cd ~/Documents/零碎兴趣/闲聊/DesktopCat
swift build -c release

# 2. 创建 .app 包结构
APP=~/Applications/DesktopCat.app
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# 3. 复制可执行文件
cp .build/release/DesktopCat "$APP/Contents/MacOS/DesktopCat"

# 4. 复制图标（如果有）
cp /path/to/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
```

### Info.plist

`$APP/Contents/Info.plist` 内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>DesktopCat</string>
    <key>CFBundleDisplayName</key>
    <string>桌面小猫</string>
    <key>CFBundleIdentifier</key>
    <string>com.cecilia.desktopcat</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>DesktopCat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

关键字段说明：
- `LSUIElement = true` → 不在 Dock 显示图标
- `NSHighResolutionCapable = true` → 支持 Retina 屏

## 皮肤文件部署

皮肤目录：`~/Library/Application Support/DesktopCat/skin/`

需要的文件：
```
skin/
├── idle.mov    # 待机视频（必须）
├── walk.mov    # 走路视频（必须）
├── sit.mov     # 坐下视频（必须）
└── pet.mov     # 被摸视频（必须）
```

视频规格：
- 格式：QuickTime MOV
- 编码：Apple ProRes 4444 / 4444 XQ
- 像素格式：yuva444p12le（带 Alpha）
- 分辨率：1080×1080
- 帧率：30fps

### 验证视频格式

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,pix_fmt \
  ~/Library/Application\ Support/DesktopCat/skin/idle.mov

# 正确输出应该是：
# codec_name=prores
# pix_fmt=yuva444p12le
```

## 设为开机自启

**方法一：系统设置**
1. 系统设置 → 通用 → 登录项
2. 点 "+" → 选择 `~/Applications/DesktopCat.app`

**方法二：命令行**
```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Users/cecilia/Applications/DesktopCat.app", hidden:false}'
```

## 更新流程

**重要：** 改完代码后，必须完整走完以下四步，.app 才会真正更新。
只用 `swift build`（debug）或者直接跑源码，.app 里的可执行文件不会变。

```bash
# 1. 编译 Release 版本
cd ~/Documents/零碎兴趣/闲聊/DesktopCat
swift build -c release

# 2. 关闭正在运行的实例
killall DesktopCat 2>/dev/null

# 3. 覆盖 .app 里的可执行文件（这步是关键，不做的话 .app 还是旧代码）
cp .build/release/DesktopCat ~/Applications/DesktopCat.app/Contents/MacOS/

# 4. 重新启动
open ~/Applications/DesktopCat.app
```

## 更换皮肤视频

1. 用 PR 导出新的带 Alpha 的 MOV 视频（ProRes 4444 + 8bpc Alpha）
2. 重命名为 idle.mov / walk.mov / sit.mov / pet.mov
3. 放到 `~/Library/Application Support/DesktopCat/skin/`
4. 在菜单栏点"重新加载皮肤"，或重启程序

## 数据位置

| 数据 | 路径 |
|------|------|
| 数据库 | `~/Library/Application Support/DesktopCat/reminders.db` |
| 皮肤文件 | `~/Library/Application Support/DesktopCat/skin/` |
| App 本体 | `~/Applications/DesktopCat.app` |

## 卸载

```bash
# 删除 App
rm -rf ~/Applications/DesktopCat.app

# 删除数据（可选）
rm -rf ~/Library/Application\ Support/DesktopCat/
```

## 故障排除

| 问题 | 原因 | 解决 |
|------|------|------|
| 改了代码但 .app 没变化 | 没有覆盖 .app 里的可执行文件 | 走完更新流程第3步 `cp .build/release/DesktopCat ~/Applications/DesktopCat.app/Contents/MacOS/` |
| 小猫不显示 | 皮肤目录没有 idle.mov | 确认文件路径正确 |
| 黑色背景 | 视频没有 Alpha 通道 | 用 ffprobe 检查 pix_fmt 是否含 `a` |
| 启动慢 | Debug 编译 | 用 `swift build -c release` |
| 图标不更新 | 系统图标缓存 | `killall Dock && killall Finder` |
| 养护数据丢失 | reminders.db 被删 | 重新设置各任务的首次日期 |
