import AppKit
import ApplicationServices

/// 全局选区监听（BUILD_SPEC §4「SelectionMonitor 触发策略」）。M1。
///
/// 用**全局鼠标监听**判断"可能刚发生了一次选择"，然后决定是否弹悬浮工具条：
/// - 左键 mouseUp 后，等一小会儿让选区状态稳定；
/// - 若 AX 能读到非空选区（原生 App）→ 弹；
/// - 若 AX 读不到（Slack/Electron）→ 用"拖拽距离 > 阈值"兜底判断可能选中了 → 弹。
///
/// 权限说明：全局**鼠标**监听不需要「输入监控」；只有全局键盘监听才要。AX 读选区用的是
/// 已授予的「辅助功能」。所以本类不引入新的权限类型。
///
/// ⚠️ 本类**不**在 mouseUp 阶段模拟 Cmd+C（会破坏剪贴板）；真正抓取推迟到用户点动作时。
@MainActor
final class SelectionMonitor {

    /// 判断"可能选中了文本" → 传出屏幕坐标（Cocoa，左下原点），供定位工具条。
    var onSelectionLikely: ((NSPoint) -> Void)?
    /// 任意一次全局 mouseDown（点到别处）→ 供上层收起已显示的工具条。
    var onMouseDown: (() -> Void)?

    private var downMonitor: Any?
    private var upMonitor: Any?
    private var downLocation: NSPoint = .zero

    private let dragThreshold: CGFloat = 6      // 拖拽超过 6pt 视为可能在选择
    private let settleDelay: TimeInterval = 0.12 // 让选区状态落地

    var isRunning: Bool { downMonitor != nil || upMonitor != nil }

    func start() {
        guard !isRunning else { return }

        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            let loc = NSEvent.mouseLocation
            Task { @MainActor in
                guard let self else { return }
                self.downLocation = loc
                self.onMouseDown?()
            }
        }

        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            let loc = NSEvent.mouseLocation
            Task { @MainActor in self?.handleMouseUp(at: loc) }
        }
    }

    func stop() {
        if let downMonitor { NSEvent.removeMonitor(downMonitor) }
        if let upMonitor { NSEvent.removeMonitor(upMonitor) }
        downMonitor = nil
        upMonitor = nil
    }

    private func handleMouseUp(at up: NSPoint) {
        let dragDistance = hypot(up.x - downLocation.x, up.y - downLocation.y)
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in
            guard let self else { return }
            let hasAXSelection = AXSelection.hasNonEmptySelection()
            if hasAXSelection || dragDistance > self.dragThreshold {
                self.onSelectionLikely?(up)
            }
        }
    }
}

/// AX 读取当前焦点元素的选中文本，仅用于**判断**是否要弹条（不做抓取）。
enum AXSelection {
    static func hasNonEmptySelection() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide,
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focusedRef) == .success,
              let focusedRef,
              CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return false
        }
        let element = focusedRef as! AXUIElement

        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                                            kAXSelectedTextAttribute as CFString,
                                            &selectedRef) == .success,
              let text = selectedRef as? String else {
            return false
        }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
