import AppKit
import SwiftUI
import Combine

/// 结果卡片状态（BUILD_SPEC §8）。M0/M1：复制（自动）/ 重写 / 关闭。「替换原文」留到 Batch B。
@MainActor
final class ResultCardModel: ObservableObject {
    enum State {
        case loading
        case result(String)
        case error(String)
    }

    @Published var state: State = .loading
    @Published var feature: Feature = .polish
    @Published var subtext: String?      // 「说人话」的〔潜台词〕小字
    @Published var variantLabel: String? // 润色语气：正式/中性/亲切

    /// 卡片标题：功能名（+ 变体，如"润色 · 正式"）。
    var title: String {
        if let variantLabel { return "\(feature.displayName) · \(variantLabel)" }
        return feature.displayName
    }

    var onRun: (() -> Void)?     // 重写（结果态）/ 重试（错误态）
    var onClose: (() -> Void)?
}

/// 管理结果卡片窗口（复用同一个窗口）。固定大小、像个对话框；可定位到工具条上方。
@MainActor
final class ResultCardController {
    let model = ResultCardModel()
    private var window: NSWindow?
    private var hasPositioned = false

    init() {
        model.onClose = { [weak self] in self?.close() }
    }

    /// 显示。`anchor` 为工具条的屏幕 frame：有则把卡片定位到它上方；无则居中（仅首次）。
    func show(anchor: NSRect? = nil) {
        let window = ensureWindow()
        if let anchor {
            positionAbove(anchor, window: window)
        } else if !hasPositioned {
            window.center()
            hasPositioned = true
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let hosting = NSHostingController(rootView: ResultCardView(model: model))
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .closable]
        win.title = "担当"
        win.isReleasedWhenClosed = false
        window = win
        return win
    }

    /// 定位到工具条上方，水平居中对齐；上方放不下则改放下方；最后夹进屏幕可见区。
    private func positionAbove(_ anchor: NSRect, window: NSWindow) {
        let size = window.frame.size
        let gap: CGFloat = 8
        var origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.maxY + gap)

        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            if origin.y + size.height > vf.maxY - 8 {
                origin.y = anchor.minY - gap - size.height   // 上方放不下 → 放下方
            }
            origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
            origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        }
        window.setFrameOrigin(origin)
    }
}

/// 结果卡片 UI（固定大小对话框）：loading / 结果(潜台词·已复制·重写·复制·关闭) / 错误(重试·关闭)。
struct ResultCardView: View {
    @ObservedObject var model: ResultCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.title)
                .font(.headline)
            Divider()
            content
        }
        .padding(16)
        .frame(width: 460, height: 400)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("正在生成…").foregroundColor(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .result(let text):
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if let sub = model.subtext, !sub.isEmpty {
                    Text(sub)
                        .font(.footnote)
                        .italic()
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let note = model.feature.riskNote {
                    Label(note, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                HStack {
                    Label("已复制到剪贴板", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Spacer()
                    Button("关闭") { model.onClose?() }
                    Button("重写") { model.onRun?() }
                    Button("复制") { copy(text) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                    Text(message)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button("关闭") { model.onClose?() }
                    Button("重试") { model.onRun?() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
