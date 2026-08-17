import AppKit
import ApplicationServices

/// 全局选区监听（BUILD_SPEC §4「SelectionMonitor 触发策略」）。M1。
///
/// 用**全局鼠标监听**判断"可能刚发生了一次选择"，只在**候选手势**上进一步确认是否真的选中了文本：
/// - 候选手势 = **拖拽超过阈值** 或 **双击/三击**（普通单击直接忽略，绝不弹）。
/// - 候选手势后：先用 AX 读选区（原生 App，免剪贴板）；AX 读不到（Slack/Electron 等）
///   再用 **Cmd+C 确认**（备份/还原剪贴板，非阻塞轮询、不冻结界面）。真读到文本才弹。
///
/// 这样：非选中的拖动→确认为空→不弹；双击选词→确认到文本→弹。
///
/// 权限说明：全局**鼠标**监听不需要「输入监控」；AX 读选区 + Cmd+C 确认用的是已授予的「辅助功能」。
@MainActor
final class SelectionMonitor {

    /// 确实选中了文本（新选区）→ 传出屏幕坐标（Cocoa，左下原点），供定位/显示工具条。
    var onSelectionLikely: ((NSPoint) -> Void)?
    /// 选区已消失 → 供上层收起工具条。
    var onSelectionGone: (() -> Void)?
    /// 查询工具条当前是否可见（决定普通单击后要不要去确认选区）。
    var isBarVisible: (() -> Bool)?

    private var downMonitor: Any?
    private var upMonitor: Any?
    private var downLocation: NSPoint = .zero

    private let dragThreshold: CGFloat = 5       // 超过 5pt 才算"拖拽"（滤掉单击抖动）
    private let settleDelay: TimeInterval = 0.08 // 让选区状态落地

    var isRunning: Bool { downMonitor != nil || upMonitor != nil }

    func start() {
        guard !isRunning else { return }

        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            let loc = NSEvent.mouseLocation
            Task { @MainActor in self?.downLocation = loc }
        }

        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            let loc = NSEvent.mouseLocation
            let clickCount = event.clickCount
            Task { @MainActor in self?.handleMouseUp(at: loc, clickCount: clickCount) }
        }
    }

    func stop() {
        if let downMonitor { NSEvent.removeMonitor(downMonitor) }
        if let upMonitor { NSEvent.removeMonitor(upMonitor) }
        downMonitor = nil
        upMonitor = nil
    }

    private func handleMouseUp(at up: NSPoint, clickCount: Int) {
        let dragDistance = hypot(up.x - downLocation.x, up.y - downLocation.y)
        let isCandidate = clickCount >= 2 || dragDistance > dragThreshold
        let barVisible = isBarVisible?() ?? false

        // 候选手势（可能是新选区）→ 判断是否要显示/重新定位。
        // 或工具条正显示中的任意单击 → 判断选区是否还在（还在就保持，没了才收起）。
        // 二者都不满足（工具条没显示时的普通单击）→ 什么都不做，避免无谓的剪贴板探测。
        guard isCandidate || barVisible else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in
            guard let self else { return }
            // 1) AX 先试（原生 App，免剪贴板）。
            if AXSelection.hasNonEmptySelection() {
                if isCandidate { self.onSelectionLikely?(up) }   // 新选区才重新定位；否则保持不动
                return
            }
            // 2) AX 读不到 → 用 Cmd+C 确认选区是否还在。
            TextGrabber.detectSelection { [weak self] hasSelection in
                Task { @MainActor in
                    guard let self else { return }
                    if hasSelection {
                        if isCandidate { self.onSelectionLikely?(up) }  // 新选区 → 显示/重定位；单击保持 → 不动
                    } else {
                        self.onSelectionGone?()                          // 选区没了 → 收起
                    }
                }
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
