// swift-tools-version:5.9
import PackageDescription

// Sidekick — macOS 菜单栏 App（M0）。
// 说明：本机只装了 Command Line Tools（无 Xcode.app），因此用 SwiftPM 构建可执行文件，
// 再由 scripts/build-app.sh 组装成标准 .app bundle 并 ad-hoc 签名。
let package = Package(
    name: "Sidekick",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Sidekick",
            path: "Sources/Sidekick"
        )
    ]
)
