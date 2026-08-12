import AppKit

/// 悬浮工具条（BUILD_SPEC §4）。
///
/// 非激活浮窗：既置顶又**不抢焦点、不丢原 App 选区**。
/// - `.nonactivatingPanel + .borderless`、`orderFrontRegardless()`。
/// - 内容用 **AppKit**（SwiftUI 控件在非 key 窗口常收不到点击）。
/// - 一排/一列功能按钮（横竖由设置决定）；含 ✕ 关闭、拖动手柄、以及「BB啥呢」二级菜单。
@MainActor
final class ActionBarPanel {

    /// 点某功能（feature + 变体 + 工具条 frame，供结果卡片定位到其上方）。
    var onFeature: ((Feature, String?, NSRect) -> Void)?
    /// 点 ✕ 关闭（上层据此关掉自动弹条）。
    var onClose: (() -> Void)?

    private var panel: NSPanel?
    private var builtVertical = Settings.barVertical

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(at screenPoint: NSPoint) {
        // 设置里横/竖变了 → 丢弃旧面板重建。
        if panel != nil, builtVertical != Settings.barVertical {
            panel?.orderOut(nil)
            panel = nil
        }
        let panel = ensurePanel()
        position(panel, near: screenPoint)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        builtVertical = Settings.barVertical
        let content = ActionBarContentView(
            items: BarItem.all,
            vertical: builtVertical,
            onFeature: { [weak self] feature, variant in
                guard let self else { return }
                let barFrame = self.panel?.frame ?? .zero
                self.hide()
                self.onFeature?(feature, variant, barFrame)
            },
            onClose: { [weak self] in
                self?.hide()
                self?.onClose?()
            }
        )

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: content.fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.level = .popUpMenu
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.worksWhenModal = false
        p.isMovableByWindowBackground = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.contentView = content
        p.setContentSize(content.fittingSize)
        panel = p
        return p
    }

    private func position(_ panel: NSPanel, near point: NSPoint) {
        let size = panel.frame.size
        var origin = NSPoint(x: point.x + 8, y: point.y + 8)

        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            origin.x = min(max(origin.x, vf.minX + 4), vf.maxX - size.width - 4)
            origin.y = min(max(origin.y, vf.minY + 4), vf.maxY - size.height - 4)
        }
        panel.setFrameOrigin(origin)
    }
}

/// 工具条内容视图：✕ + 拖动手柄 + 功能按钮（含分组的二级菜单）。
///
/// 拖动：`hitTest` 把非按钮区域交给本视图，`mouseDown` 里 `performDrag`；按钮区域照常响应点击。
private final class ActionBarContentView: NSView {
    private let onFeature: (Feature, String?) -> Void
    private let onClose: () -> Void

    private var clickable: [NSButton] = []                        // 所有可点按钮（拖动 hitTest 时排除）
    private var featureOf: [ObjectIdentifier: Feature] = [:]      // 单功能按钮 → 功能
    private var groupOf: [ObjectIdentifier: [BarAction]] = [:]    // 分组按钮 → 二级菜单项

    init(items: [BarItem], vertical: Bool,
         onFeature: @escaping (Feature, String?) -> Void,
         onClose: @escaping () -> Void) {
        self.onFeature = onFeature
        self.onClose = onClose
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        // 顶部/首端：拖动手柄 + ✕。
        let grip = NSImageView(image: NSImage(systemSymbolName: "line.3.horizontal",
                                              accessibilityDescription: "拖动") ?? NSImage())
        grip.contentTintColor = .tertiaryLabelColor

        let close = FirstMouseButton()
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭")
        close.bezelStyle = .circular
        close.controlSize = .small
        close.target = self
        close.action = #selector(closeTapped)
        clickable.append(close)

        let header = NSStackView(views: vertical ? [grip, NSView(), close] : [grip, close])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        if vertical, header.views.count == 3 {
            header.views[1].setContentHuggingPriority(.defaultLow, for: .horizontal) // 中间 spacer 撑开
        }

        let stack = NSStackView()
        stack.orientation = vertical ? .vertical : .horizontal
        stack.alignment = vertical ? .width : .centerY
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)

        for item in items {
            switch item {
            case .single(let feature):
                let button = makeButton(title: feature.displayName, action: #selector(tapSingle(_:)))
                featureOf[ObjectIdentifier(button)] = feature
                stack.addArrangedSubview(button)
            case .group(let title, let actions):
                let button = makeButton(title: title, action: #selector(tapGroup(_:)))
                groupOf[ObjectIdentifier(button)] = actions
                stack.addArrangedSubview(button)
            }
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layoutSubtreeIfNeeded()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = FirstMouseButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        clickable.append(button)
        return button
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // 按钮之外的区域交给本视图（用于拖动）。
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if let hit, clickable.contains(where: { $0 === hit }) { return hit }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    @objc private func tapSingle(_ sender: NSButton) {
        if let feature = featureOf[ObjectIdentifier(sender)] { onFeature(feature, nil) }
    }

    @objc private func tapGroup(_ sender: NSButton) {
        guard let actions = groupOf[ObjectIdentifier(sender)] else { return }
        let menu = NSMenu()
        for action in actions {
            let item = NSMenuItem(title: action.title, action: #selector(pickGrouped(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    @objc private func pickGrouped(_ sender: NSMenuItem) {
        if let action = sender.representedObject as? BarAction {
            onFeature(action.feature, action.variant)
        }
    }

    @objc private func closeTapped() { onClose() }
}

/// 让按钮在非 key 窗口里接受"第一下点击"。
private final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
