import AppKit
import SwiftUI

/// 设置窗口（SwiftUI，托管在 NSWindow 里）。M0 只有一项：Gemini API Key。
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable]
            win.title = "担当 · 设置"
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// 设置页：填 API Key → 存 Keychain；选择快档/强档模型（选项来自你 Key 实际可用的模型）。
struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var savedFlash = false

    @State private var fastModel = Settings.fastModel
    @State private var strongModel = Settings.strongModel
    @State private var availableModels: [String] = []
    @State private var modelStatus = ""
    @State private var refreshing = false

    @State private var barVertical = Settings.barVertical
    @State private var langRefresh = 0   // 触发语言下拉重绘

    /// 可设置输出语言的功能。（阴阳已并入「打发丫」立场，不单列。）
    private let languageFeatures: [Feature] = [.plainSpeak, .whoSaidWhat, .relevance, .polish, .presence, .reply]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Gemini API Key").font(.headline)

                SecureField("在此粘贴你的 Gemini API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                Label("请使用 Gemini 付费 API Key，勿用免费 AI Studio Key。",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundColor(.secondary)

                HStack(spacing: 10) {
                    Button("保存到 Keychain") { save() }
                        .keyboardShortcut(.defaultAction)
                    if savedFlash { Text("已保存 ✓").foregroundColor(.green) }
                    Spacer()
                    if !apiKey.isEmpty { Button("清除") { clear() } }
                }

                Divider()

                // 模型档位
                Text("模型档位").font(.headline)
                Text("翻译/总结/改写用「快档」；「关我毛事」「刷存在感」用「强档」。先刷新，再选择。")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button(refreshing ? "刷新中…" : "刷新可用模型") { refreshModels() }
                        .disabled(refreshing)
                    if !modelStatus.isEmpty {
                        Text(modelStatus).font(.caption).foregroundColor(.secondary)
                    }
                }
                Picker("快档", selection: $fastModel) {
                    ForEach(modelOptions, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: fastModel) { Settings.fastModel = $0 }
                Picker("强档", selection: $strongModel) {
                    ForEach(modelOptions, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: strongModel) { Settings.strongModel = $0 }

                Divider()

                // 悬浮条排列
                Text("悬浮条").font(.headline)
                Picker("排列方式", selection: $barVertical) {
                    Text("竖排").tag(true)
                    Text("横排").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: barVertical) { Settings.barVertical = $0 }
                Text("改动在下次划词弹出时生效。")
                    .font(.caption).foregroundColor(.secondary)

                Divider()

                // 每个功能的输出语言
                Text("输出语言").font(.headline)
                Text("「跟随原文」= 与原文/对话相同的语言。")
                    .font(.caption).foregroundColor(.secondary)
                ForEach(languageFeatures, id: \.self) { feature in
                    HStack {
                        Text(feature.displayName)
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: languageBinding(feature)) {
                            ForEach(Settings.languageOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
                .id(langRefresh)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷键：\(Settings.hotKeyDisplay) — 在任意 App 选中文字后按下即可润色。")
                    Text("Key 只存于本机 Keychain，不会上传；仅在你触发时把选中文本发往 Gemini。")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding(20)
            .frame(width: 460, alignment: .leading)
        }
        .frame(width: 460, height: 560)
        .onAppear { apiKey = Keychain.apiKey() ?? "" }
    }

    private func languageBinding(_ feature: Feature) -> Binding<String> {
        Binding(
            get: { Settings.outputLanguage(for: feature) },
            set: { Settings.setOutputLanguage($0, for: feature); langRefresh += 1 }
        )
    }

    /// 下拉选项：已拉取到的模型；并保证当前选中值一定在列表里（否则下拉会显示为空）。
    private var modelOptions: [String] {
        var options = availableModels
        for model in [fastModel, strongModel] where !options.contains(model) {
            options.insert(model, at: 0)
        }
        return options
    }

    private func refreshModels() {
        guard let key = Keychain.apiKey(), !key.isEmpty else {
            modelStatus = "请先保存 API Key"
            return
        }
        refreshing = true
        modelStatus = ""
        Task {
            do {
                let models = try await GeminiClient.listModels(apiKey: key)
                await MainActor.run {
                    availableModels = models
                    modelStatus = "找到 \(models.count) 个可用模型"
                    refreshing = false
                }
            } catch {
                await MainActor.run {
                    let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    modelStatus = "刷新失败：\(msg)"
                    refreshing = false
                }
            }
        }
    }

    private func save() {
        Keychain.setAPIKey(apiKey)
        // 回读一次，反映实际保存结果（空串会被当作删除）。
        apiKey = Keychain.apiKey() ?? ""
        savedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFlash = false }
    }

    private func clear() {
        Keychain.deleteAPIKey()
        apiKey = ""
    }
}
