import AppKit
import SwiftUI

/// Profile 编辑窗口（SwiftUI，托管在 NSWindow）。供功能 6/7 使用。
@MainActor
final class ProfileWindow {
    static let shared = ProfileWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: ProfileView())
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable]
            win.title = "个人资料"
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Profile 编辑页（PRD §6）。填的内容只用于本机组装 prompt，会随触发一起发往模型。
struct ProfileView: View {
    @State private var profile = Profile.load()
    @State private var savedFlash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("个人资料").font(.headline)
            Text("用于「关我毛事？」「刷存在感」。只存本机，仅在你触发这些功能时随选中文本一起发往模型。")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            field("姓名 / 昵称", text: $profile.name)
            field("公司角色、职级", text: $profile.role, placeholder: "如：产品经理 / P6")
            field("所在团队、主要职责", text: $profile.team)

            Text("关注事项 / 负责的项目").font(.subheadline)
            TextEditor(text: $profile.focus)
                .font(.body)
                .frame(height: 64)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.3)))

            field("语言偏好", text: $profile.languages, placeholder: "如：母语中文，工作语言中英")

            HStack {
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                if savedFlash {
                    Text("已保存 ✓").foregroundColor(.green)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder
    private func field(_ title: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        Profile.save(profile)
        savedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFlash = false }
    }
}
