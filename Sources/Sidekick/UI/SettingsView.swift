import AppKit
import SwiftUI

/// 设置窗口（SwiftUI，托管在 NSWindow 里）。
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

/// 设置页：选厂商 → 填对应 Key（存 Keychain）→ 选/填快档、强档模型；每功能输出语言；悬浮条排列。
struct SettingsView: View {
    @State private var provider = Settings.provider
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var fastModel = ""
    @State private var strongModel = ""
    @State private var savedFlash = false

    @State private var availableModels: [String] = []
    @State private var modelStatus = ""
    @State private var refreshing = false

    @State private var barVertical = Settings.barVertical
    @State private var langRefresh = 0

    private let languageFeatures: [Feature] = [.plainSpeak, .whoSaidWhat, .relevance, .polish, .presence, .reply]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // MARK: 厂商
                Text("模型厂商").font(.headline)
                Picker("厂商", selection: $provider) {
                    ForEach(AIProvider.allCases, id: \.self) { p in Text(p.displayName).tag(p) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: provider) { newValue in
                    Settings.provider = newValue
                    loadProviderFields()
                }

                // MARK: Key
                Text("API Key").font(.headline)
                SecureField(provider.keyHint, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                if provider == .gemini {
                    Label("请使用 Gemini 付费 API Key，勿用免费 AI Studio Key。",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundColor(.secondary)
                }
                HStack(spacing: 10) {
                    Button("保存到 Keychain") { save() }
                        .keyboardShortcut(.defaultAction)
                    if savedFlash { Text("已保存 ✓").foregroundColor(.green) }
                    Spacer()
                    if !apiKey.isEmpty { Button("清除") { clear() } }
                }

                // MARK: Base URL（OpenAI 兼容）
                if provider.usesBaseURL {
                    Text("Base URL").font(.headline)
                    TextField(provider.defaultBaseURL, text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: baseURL) { Settings.setBaseURL($0, for: provider) }
                    Text("指向不同的 OpenAI 兼容厂商，如 DeepSeek(api.deepseek.com/v1)、xAI(api.x.ai/v1)。")
                        .font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // MARK: 模型档位
                Text("模型档位").font(.headline)
                Text("翻译/总结/改写用「快档」；「关我毛事」「刷存在感」用「强档」。可直接填模型名，或点「列出可用模型」再从列表选。")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(refreshing ? "列出中…" : "列出可用模型") { refreshModels() }
                        .disabled(refreshing)
                    if !modelStatus.isEmpty {
                        Text(modelStatus).font(.caption).foregroundColor(.secondary)
                    }
                }

                modelRow("快档", text: $fastModel, tier: .fast)
                modelRow("强档", text: $strongModel, tier: .strong)

                Divider()

                // MARK: 悬浮条排列
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

                // MARK: 每功能输出语言
                Text("输出语言").font(.headline)
                Text("「跟随原文」= 与原文/对话相同的语言。")
                    .font(.caption).foregroundColor(.secondary)
                ForEach(languageFeatures, id: \.self) { feature in
                    HStack {
                        Text(feature.displayName).frame(width: 120, alignment: .leading)
                        Picker("", selection: languageBinding(feature)) {
                            ForEach(Settings.languageOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
                .id(langRefresh)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷键：\(Settings.hotKeyDisplay) — 在任意 App 选中文字后按下即可触发。")
                    Text("Key 只存于本机 Keychain，不会上传；仅在你触发时把选中文本发往所选模型厂商。")
                }
                .font(.footnote).foregroundColor(.secondary)
            }
            .padding(20)
            .frame(width: 460, alignment: .leading)
        }
        .frame(width: 460, height: 600)
        .onAppear { loadProviderFields() }
    }

    // MARK: - 子视图

    @ViewBuilder
    private func modelRow(_ label: String, text: Binding<String>, tier: ModelTier) -> some View {
        HStack {
            Text(label).frame(width: 44, alignment: .leading)
            TextField("模型名", text: text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) { Settings.setModel($0, tier: tier, for: provider) }
            Menu("列表") {
                ForEach(availableModels, id: \.self) { m in
                    Button(m) { text.wrappedValue = m; Settings.setModel(m, tier: tier, for: provider) }
                }
            }
            .frame(width: 64)
            .disabled(availableModels.isEmpty)
        }
    }

    private func languageBinding(_ feature: Feature) -> Binding<String> {
        Binding(
            get: { Settings.outputLanguage(for: feature) },
            set: { Settings.setOutputLanguage($0, for: feature); langRefresh += 1 }
        )
    }

    // MARK: - 逻辑

    /// 切换厂商 / 首次出现时，把该厂商已存的 Key、Base URL、模型名读进来。
    private func loadProviderFields() {
        apiKey = Keychain.apiKey(for: provider) ?? ""
        baseURL = Settings.baseURL(for: provider)
        fastModel = Settings.model(.fast, for: provider)
        strongModel = Settings.model(.strong, for: provider)
        availableModels = []
        modelStatus = ""
    }

    private func refreshModels() {
        let key = apiKey.isEmpty ? (Keychain.apiKey(for: provider) ?? "") : apiKey
        guard !key.isEmpty else { modelStatus = "请先填/存 API Key"; return }
        let p = provider
        let base = provider.usesBaseURL ? baseURL : ""
        refreshing = true
        modelStatus = ""
        Task {
            do {
                let models = try await AIClient.listModels(provider: p, apiKey: key, baseURL: base)
                await MainActor.run {
                    availableModels = models
                    modelStatus = "找到 \(models.count) 个模型（点「列表」选）"
                    refreshing = false
                }
            } catch {
                await MainActor.run {
                    let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    modelStatus = "列出失败：\(msg)"
                    refreshing = false
                }
            }
        }
    }

    private func save() {
        Keychain.setAPIKey(apiKey, for: provider)
        apiKey = Keychain.apiKey(for: provider) ?? ""   // 回读（空串=删除）
        savedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFlash = false }
    }

    private func clear() {
        Keychain.deleteAPIKey(for: provider)
        apiKey = ""
    }
}
