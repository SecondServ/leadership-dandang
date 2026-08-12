import AppKit
import SwiftUI

/// 「打发丫」输入面板（原帮我回复，BUILD_SPEC §4.4 / §7.4）。功能 4（交互式）。
///
/// 立场已在工具条二级菜单选好；本面板只收集「回复的大致方向」（可留空）。
/// 流程：抓好选中文本 → 弹本面板 → 生成 → 结果卡片。
@MainActor
final class ReplyComposerController {
    let model = ReplyComposerModel()
    private var window: NSWindow?

    /// 点「生成」的回调：回复方向（立场已知）。
    var onGenerate: ((_ intent: String) -> Void)?

    func show(context: String, stance: String) {
        model.context = context
        model.stance = stance
        model.intent = ""

        if window == nil {
            let view = ReplyComposerView(
                model: model,
                onGenerate: { [weak self] in
                    guard let self else { return }
                    self.onGenerate?(self.model.intent)
                },
                onCancel: { [weak self] in self?.close() }
            )
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable]
            win.title = "打发丫"
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }
}

@MainActor
final class ReplyComposerModel: ObservableObject {
    @Published var context = ""
    @Published var intent = ""
    @Published var stance = "同意"
}

struct ReplyComposerView: View {
    @ObservedObject var model: ReplyComposerModel
    let onGenerate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("打发丫").font(.headline)
                Spacer()
                Text("立场：\(model.stance)")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Text("选中的内容（单条就回它；多人对话则冲着最后一句回）：")
                .font(.caption).foregroundColor(.secondary)
            ScrollView {
                Text(model.context)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 96)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.25)))

            Text("回复的大致方向（可留空，留空则按立场自拟）").font(.caption).foregroundColor(.secondary)
            TextField("一句话说清你想往哪个方向回", text: $model.intent)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                Button("生成") { onGenerate() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
