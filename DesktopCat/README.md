# 🐱 DesktopCat — 桌面小猫

一只住在你桌面上的小猫：眼珠会跟着鼠标转，点它会"喵~"一声，还能帮你记住猫咪的内驱、外驱、疫苗时间。

## 怎么运行

打开终端，进入这个文件夹，然后：

```bash
swift run
```

第一次会编译（约半分钟），之后小猫就出现在屏幕右下角，顶部菜单栏会出现一个爪印图标 🐾。

## 怎么用

| 操作 | 效果 |
|---|---|
| 点菜单栏爪印 → 显示/隐藏小猫 | 控制小猫出现和消失 |
| 移动鼠标 | 小猫的眼珠跟着你转 |
| 点击小猫 | 弹一下 + "喵~" 气泡 + 音效 |
| 按住小猫拖动 | 把它挪到你喜欢的位置 |
| 点菜单栏爪印 → 提醒事项… | 添加/管理猫咪提醒（内驱、外驱等） |
| 点菜单栏爪印 → 退出 | 关闭程序 |

提醒到期时，右上角会弹系统通知。数据存在本地 SQLite 数据库里
（`~/Library/Application Support/DesktopCat/reminders.db`），重启电脑也不会丢。

## 每个文件是干什么的

```
DesktopCat/
├── Package.swift                  项目说明书（名字、系统要求、代码位置）
└── Sources/DesktopCat/
    ├── main.swift                 程序入口，启动 App
    ├── AppDelegate.swift          总管家：透明窗口、菜单栏、提醒定时器
    ├── CatView.swift              小猫本体：画猫、眼神跟随、点击互动
    ├── ReminderStore.swift        本地数据库：SQLite 增删改查 + 到期检查
    └── RemindersView.swift        提醒管理界面：添加、勾选、删除
```

## 核心原理（对应你要的 4 个功能）

### 1. 小猫出现/消失
小猫其实是一个**透明、无边框、置顶的窗口**（`AppDelegate.swift` 的 `setupCatWindow`）：

- `styleMask: [.borderless]` → 没有标题栏
- `backgroundColor = .clear` → 背景透明，只看得见猫
- `level = .floating` → 永远浮在其他窗口上面

"消失/出现"就是对这个窗口调用 `orderOut`（隐藏）/ `makeKeyAndOrderFront`（显示）。

### 2. 眼神跟随鼠标
`CatView.swift` 里的 `EyeTracker`，每秒 30 次做三件事：

1. `NSEvent.mouseLocation` 读鼠标在屏幕上的位置
2. 算出鼠标相对猫眼的方向（三角函数）
3. 让瞳孔沿这个方向偏移，最多 6 像素（不能跑出眼眶）

### 3. 点击互动
SwiftUI 的 `.onTapGesture` 监听点击，触发三件事：播放音效、身体弹跳动画（`scaleEffect` + 弹簧动画）、显示"喵~"气泡。另外小猫每 3~6 秒会随机眨眼，显得是活的。

### 4. 本地数据库
用 macOS 自带的 **SQLite**（单文件数据库，不用安装任何东西）。
`ReminderStore.swift` 里就是标准的增删改查 SQL：

```sql
CREATE TABLE reminders (id, title, due_date, is_done, notified);
INSERT INTO reminders (title, due_date) VALUES (?, ?);
SELECT ... / UPDATE ... / DELETE ...
```

`AppDelegate` 里的定时器每 60 秒查一次"到期 && 未完成 && 没提醒过"的记录，弹系统通知。

## 想继续折腾？一些改进方向

- **换毛色**：改 `CatView.swift` 里的 `catColor`
- **加尾巴摇摆动画**：参考耳朵的 `EarShape`，用 `Path` 画条尾巴加旋转动画
- **开机自启**：系统设置 → 通用 → 登录项，把编译出来的程序加进去
- **打包成双击就能开的 App**：`swift build -c release` 后把可执行文件包成 `.app` 目录结构
