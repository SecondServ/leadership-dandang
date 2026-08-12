import AppKit
import Carbon   // kVK_ANSI_C

/// 抓取当前选中文本。
///
/// M0 只实现 **Cmd+C 回退方案**（BUILD_SPEC §5）：
/// 备份剪贴板 → 合成 Cmd+C → 读剪贴板 → 还原原剪贴板。
/// AX 直读选区（`kAXSelectedTextAttribute`）留到 M1。
///
/// 前置条件：调用时原 App 仍在前台、选区仍在（所以触发路径上不要先激活本 App/弹窗）。
/// 合成按键需要「辅助功能」权限。
enum TextGrabber {

    /// 返回抓到的选中文本；没抓到（或没有选区）返回 nil。
    static func grabViaCopyFallback() -> String? {
        let pb = NSPasteboard.general

        // 1. 备份现有剪贴板（尽量无损：保留每个 item 的所有类型）。
        let backup = backup(pb)
        let startCount = pb.changeCount

        // 2. 合成 Cmd+C。
        postCommandC()

        // 3. 轮询等待剪贴板变化（最多 ~400ms）。changeCount 变了才认为复制成功。
        var changed = false
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline {
            if pb.changeCount != startCount { changed = true; break }
            usleep(15_000) // 15ms
        }
        if changed { usleep(20_000) } // 给内容落地一点缓冲

        // 只在确实发生复制时读取，避免把用户无关的旧剪贴板误当成"选区"。
        let grabbed = changed ? pb.string(forType: .string) : nil

        // 4. 还原原剪贴板。
        restore(pb, from: backup)

        let trimmed = grabbed?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    // MARK: - 剪贴板备份/还原

    private struct ItemBackup {
        let entries: [(NSPasteboard.PasteboardType, Data)]
    }

    private static func backup(_ pb: NSPasteboard) -> [ItemBackup] {
        guard let items = pb.pasteboardItems else { return [] }
        return items.map { item in
            var entries: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    entries.append((type, data))
                }
            }
            return ItemBackup(entries: entries)
        }
    }

    private static func restore(_ pb: NSPasteboard, from backup: [ItemBackup]) {
        pb.clearContents()
        guard !backup.isEmpty else { return }
        let items: [NSPasteboardItem] = backup.map { b in
            let item = NSPasteboardItem()
            for (type, data) in b.entries {
                item.setData(data, forType: type)
            }
            return item
        }
        pb.writeObjects(items)
    }

    // MARK: - 合成 Cmd+C

    private static func postCommandC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cKey = CGKeyCode(kVK_ANSI_C)

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
