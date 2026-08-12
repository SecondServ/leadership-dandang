import AppKit

/// 菜单栏常驻入口（BUILD_SPEC §3）。
///
/// 标记 `@MainActor`：AppKit 类型在当前 SDK 均为主线程隔离，本类的 UI/状态操作也应在主线程。
/// `@main` + `static main()` 让程序入口跑在 main actor 上（与 SwiftUI `App` 同理）。
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var autoPopMenuItem: NSMenuItem?
    private let appState = AppState()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // 无 Dock 图标（与 Info.plist LSUIElement 一致）
        app.run()
        _ = delegate                        // 持有到 run() 返回（delegate 属性是 weak）
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotKey()
        appState.onAutoPopChanged = { [weak self] enabled in
            self?.autoPopMenuItem?.state = enabled ? .on : .off
        }
        appState.setupAutoPop()   // M1：划词自动弹条
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "wand.and.stars",
                                   accessibilityDescription: "担当")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "体面一点（选中文本）  \(Settings.hotKeyDisplay)",
                     action: #selector(triggerPolish), keyEquivalent: "")

        let autoPop = NSMenuItem(title: "划词自动弹条",
                                 action: #selector(toggleAutoPop), keyEquivalent: "")
        autoPop.state = Settings.autoPopEnabled ? .on : .off
        menu.addItem(autoPop)
        autoPopMenuItem = autoPop

        menu.addItem(.separator())
        menu.addItem(withTitle: "个人资料…", action: #selector(openProfile), keyEquivalent: "")
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出担当", action: #selector(quit), keyEquivalent: "q")
        for mi in menu.items { mi.target = self }

        item.menu = menu
        statusItem = item
    }

    // MARK: - 全局快捷键

    private func setupHotKey() {
        let hk = HotKey { [weak self] in
            // Carbon 回调经 HotKey 内部派发到主线程；再显式跳 MainActor 以满足隔离要求。
            Task { @MainActor in self?.appState.runPolishFlow() }
        }
        hk.register()
        hotKey = hk
    }

    // MARK: - Actions

    @objc private func triggerPolish() { appState.runPolishFlow() }
    @objc private func openSettings() { appState.openSettings() }
    @objc private func openProfile() { appState.openProfile() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleAutoPop() {
        appState.setAutoPop(!Settings.autoPopEnabled)   // 菜单勾选状态由 onAutoPopChanged 同步
    }
}
