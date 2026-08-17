import AppKit

/// 全局状态 + 单次功能流程编排。
///
/// 流程（BUILD_SPEC §3 数据流）：
///   触发（快捷键/菜单/工具条）→ 权限检查 → Key 检查 →（需要则）Profile 检查
///   → TextGrabber(Cmd+C 回退) → Prompts 组装 → GeminiClient → ResultCardPanel
///
/// 人在环中：全程只做剪贴板读取 + 结果展示，绝不自动向任何 App 发送。
@MainActor
final class AppState {
    private let resultCard = ResultCardController()
    private let actionBar = ActionBarPanel()
    private let selectionMonitor = SelectionMonitor()
    private let replyComposer = ReplyComposerController()

    /// 自动弹条开关变化时通知（供菜单勾选状态同步）。
    var onAutoPopChanged: ((Bool) -> Void)?

    /// 打开设置窗口。
    func openSettings() {
        SettingsWindow.shared.show()
    }

    /// 打开 Profile 窗口。
    func openProfile() {
        ProfileWindow.shared.show()
    }

    // MARK: - 划词自动弹条（M1）

    /// 接线并按设置启动"划词自动弹条"。应用启动时调用一次。
    func setupAutoPop() {
        actionBar.onFeature = { [weak self] feature, variant, barFrame in
            self?.runFeature(feature, variant: variant, anchor: barFrame)
        }
        actionBar.onClose = { [weak self] in self?.setAutoPop(false) }   // 悬浮条 ✕：关掉自动弹条
        selectionMonitor.isBarVisible = { [weak self] in self?.actionBar.isVisible ?? false }
        selectionMonitor.onSelectionLikely = { [weak self] point in
            guard let self, Settings.autoPopEnabled else { return }
            self.actionBar.show(at: point)
        }
        selectionMonitor.onSelectionGone = { [weak self] in self?.actionBar.hide() }
        applyAutoPop(Settings.autoPopEnabled)
    }

    /// 开关自动弹条（同时持久化）。关闭后仍可用快捷键触发；菜单栏可重新开启。
    func setAutoPop(_ enabled: Bool) {
        Settings.autoPopEnabled = enabled
        applyAutoPop(enabled)
        onAutoPopChanged?(enabled)
    }

    private func applyAutoPop(_ enabled: Bool) {
        if enabled {
            selectionMonitor.start()
        } else {
            selectionMonitor.stop()
            actionBar.hide()
        }
    }

    // MARK: - 功能触发

    /// 「润色」快捷键/菜单入口（保持旧名，转调通用流程）。
    func runPolishFlow() { runFeature(.polish) }

    /// 触发某个功能的全链路。均在主线程调用。
    /// - Parameters:
    ///   - variant: 变体（润色语气：正式/中性/亲切）；无则用默认。
    ///   - anchor: 触发它的工具条 frame（用于把结果卡片定位到工具条上方）；快捷键/菜单触发时为 nil。
    func runFeature(_ feature: Feature, variant: String? = nil, anchor: NSRect? = nil) {
        // 1. 权限：合成 Cmd+C 需要「辅助功能」。
        guard PermissionPrompt.isAccessibilityTrusted() else {
            PermissionPrompt.showAccessibilityNeeded()
            return
        }

        // 2. Key：未配置（当前厂商）→ 引导去设置。
        guard let apiKey = Keychain.apiKey(for: Settings.provider), !apiKey.isEmpty else {
            promptMissingKey()
            return
        }

        // 3. Profile：功能 6 必须先填资料。
        if feature.requiresProfile && Profile.current.isEmpty {
            promptMissingProfile(feature)
            return
        }

        // 4. 抓文本：必须在弹任何窗口/激活本 App 之前做，否则会打断源 App 的选区/焦点。
        guard let text = TextGrabber.grabViaCopyFallback() else {
            resultCard.model.feature = feature
            resultCard.model.variantLabel = variant
            resultCard.model.subtext = nil
            resultCard.model.onRun = nil
            resultCard.model.state = .error("没有读到选中的文本。请先在其它 App 里选中一段文字，再触发。")
            resultCard.show(anchor: anchor)
            return
        }

        // 5a. 交互式（打发丫）：立场已从二级菜单选好（variant），先弹面板收集"大致方向"，再生成。
        if feature.isInteractive {
            showReplyComposer(text: text, apiKey: apiKey, stance: variant ?? "同意", anchor: anchor)
            return
        }

        // 5b. 其余：直接调模型 + 展示。
        start(feature, text: text, apiKey: apiKey, variant: variant, anchor: anchor)
    }

    private func showReplyComposer(text: String, apiKey: String, stance: String, anchor: NSRect?) {
        replyComposer.onGenerate = { [weak self] intent in
            guard let self else { return }
            self.replyComposer.close()
            self.start(.reply, text: text, apiKey: apiKey, variant: stance, anchor: anchor, reply: (intent, stance))
        }
        replyComposer.show(context: text, stance: stance)
    }

    /// 发起请求（"重写/重试"复用同一段文本、变体、立场与定位）。
    private func start(_ feature: Feature, text: String, apiKey: String, variant: String?, anchor: NSRect?,
                       reply: (intent: String, stance: String)? = nil) {
        resultCard.model.feature = feature
        resultCard.model.variantLabel = variant
        resultCard.model.subtext = nil
        resultCard.model.onRun = { [weak self] in
            self?.start(feature, text: text, apiKey: apiKey, variant: variant, anchor: anchor, reply: reply)
        }
        resultCard.model.state = .loading
        resultCard.show(anchor: anchor)

        let provider = Settings.provider
        let model = Settings.model(feature.tier)
        let baseURL = Settings.baseURL(for: provider)
        let language = Settings.outputLanguage(for: feature)
        var system = Prompts.systemPrompt(for: feature)
        let user: String
        if feature == .reply, let reply {
            if let extra = Prompts.replySystemExtra(stance: reply.stance) { system += " " + extra }
            user = Prompts.replyPrompt(text: text, intent: reply.intent, stance: reply.stance,
                                       langPolicy: Prompts.replyLangPolicy(language))
        } else {
            user = Prompts.userPrompt(for: feature, text: text, profile: Profile.current, language: language, variant: variant)
        }
        let temperature = feature.temperature
        let thinkingBudget = feature.thinkingBudget

        Task {
            do {
                let raw = try await AIClient.generate(provider: provider, apiKey: apiKey, model: model, baseURL: baseURL,
                                                      system: system, user: user,
                                                      temperature: temperature, thinkingBudget: thinkingBudget)
                await MainActor.run {
                    let (main, subtext) = self.splitOutput(raw, feature: feature)
                    // 人在环中：只把结果写进剪贴板（不代发）。用户切回原 App 自行粘贴。
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(main, forType: .string)
                    self.resultCard.model.subtext = subtext
                    self.resultCard.model.state = .result(main)
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run { self.resultCard.model.state = .error(message) }
            }
        }
    }

    /// 拆分「说人话」输出：正文 + 注释（〔潜台词〕、〔黑话/缩写〕）。其它功能原样返回。
    /// 只有正文进剪贴板；注释只在卡片上展示。
    private func splitOutput(_ raw: String, feature: Feature) -> (main: String, subtext: String?) {
        guard feature.producesSubtext, let range = raw.range(of: "〔潜台词〕") else {
            return (raw, nil)
        }
        let main = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        // 从「〔潜台词〕」起到结尾都算注释（含随后的〔黑话/缩写〕），原样展示。
        let sub = String(raw[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (main.isEmpty ? raw : main, sub.isEmpty ? nil : sub)
    }

    // MARK: - 引导

    private func promptMissingKey() {
        let alert = NSAlert()
        alert.messageText = "还没有填 API Key"
        alert.informativeText = "请打开「设置」，选择模型厂商并填入对应的 API Key（\(Settings.provider.displayName)）。"
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    private func promptMissingProfile(_ feature: Feature) {
        let alert = NSAlert()
        alert.messageText = "「\(feature.displayName)」需要先填个人资料"
        alert.informativeText = "这个功能要结合你的角色/职责来判断。请先在「个人资料」里填写。"
        alert.addButton(withTitle: "填写资料")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openProfile()
        }
    }
}
