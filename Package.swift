// swift-tools-version:5.9
// 这个文件是项目的"说明书"：告诉 Swift 这个项目叫什么、支持什么系统、代码在哪。
import PackageDescription

let package = Package(
    name: "DesktopCat",
    platforms: [
        .macOS(.v13)   // 最低支持 macOS 13
    ],
    targets: [
        // executableTarget 表示这是一个可以直接运行的程序（而不是给别人用的库）
        .executableTarget(
            name: "DesktopCat",
            path: "Sources/DesktopCat"
        )
    ]
)
