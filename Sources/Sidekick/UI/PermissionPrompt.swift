import AppKit
import ApplicationServices

/// 权限引导（BUILD_SPEC §2）。
///
/// M0 真正需要的是「辅助功能」权限：合成 Cmd+C 读取选区要用它。
/// （输入监控是 M1 做全局鼠标监听时才需要，本期不涉及。）
enum PermissionPrompt {

    /// 当前是否已获「辅助功能」信任。
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// 弹说明，并提供跳「系统设置 → 隐私与安全性 → 辅助功能」的按钮。
    static func showAccessibilityNeeded() {
        let alert = NSAlert()
        alert.messageText = "需要「辅助功能」权限"
        alert.informativeText = """
        担当 需要「辅助功能」权限，用来在你按快捷键时模拟 Cmd+C，读取你当前选中的文本。

        请在「系统设置 → 隐私与安全性 → 辅助功能」中勾选 担当（可能仍显示为 Sidekick），然后重新按快捷键（⌥⌘P）。

        隐私说明：我们只在你按下快捷键的那一刻读取选中文本，不做任何后台采集。
        """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
            // 同时触发系统原生提示，把本 App 加进「辅助功能」列表。
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    private static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
