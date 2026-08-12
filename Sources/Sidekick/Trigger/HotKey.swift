import AppKit
import Carbon

/// 全局快捷键（BUILD_SPEC §1：自封装 Carbon `RegisterEventHotKey`，无第三方依赖）。
///
/// 关键点：`RegisterEventHotKey` 是系统级热键，**注册与接收本身不需要辅助功能/输入监控权限**。
/// （需要权限的是后续 TextGrabber 里合成 Cmd+C 的那一步。）
///
/// 默认绑定 ⌥⌘P。
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: () -> Void

    // ⌥⌘P
    private let keyCode = UInt32(kVK_ANSI_P)
    private let modifiers = UInt32(optionKey | cmdKey)
    private let signature: OSType = 0x53444B31 // 'SDK1'
    private let hotKeyID: UInt32 = 1

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    /// 安装事件处理器并注册热键。
    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData, let event else { return noErr }
                let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()

                var receivedID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedID
                )
                if receivedID.id == me.hotKeyID {
                    DispatchQueue.main.async { me.handler() }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        let id = EventHotKeyID(signature: signature, id: hotKeyID)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKeyRef = nil
        eventHandler = nil
    }

    deinit { unregister() }
}
