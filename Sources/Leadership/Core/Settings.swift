import Foundation

/// 全局设置常量（BUILD_SPEC §6）。M0 先用常量，后续里程碑再做成可配置项。
enum Settings {
    // MARK: - 大模型厂商与模型（可在设置页切换，存 UserDefaults）

    /// 当前使用的厂商。默认 Gemini。
    static var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: "aiProvider") ?? "") ?? .gemini }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "aiProvider") }
    }

    /// OpenAI 兼容端点的 Base URL（其它厂商不用）。
    static func baseURL(for provider: AIProvider) -> String {
        guard provider.usesBaseURL else { return "" }
        return UserDefaults.standard.string(forKey: "baseURL.\(provider.rawValue)") ?? provider.defaultBaseURL
    }
    static func setBaseURL(_ url: String, for provider: AIProvider) {
        UserDefaults.standard.set(url, forKey: "baseURL.\(provider.rawValue)")
    }

    /// 某厂商某档位的模型名（每厂商各自记忆）。
    static func model(_ tier: ModelTier, for provider: AIProvider) -> String {
        let key = "model.\(tier == .fast ? "fast" : "strong").\(provider.rawValue)"
        let fallback = tier == .fast ? provider.defaultFastModel : provider.defaultStrongModel
        return UserDefaults.standard.string(forKey: key) ?? fallback
    }
    static func setModel(_ name: String, tier: ModelTier, for provider: AIProvider) {
        let key = "model.\(tier == .fast ? "fast" : "strong").\(provider.rawValue)"
        UserDefaults.standard.set(name, forKey: key)
    }

    /// 当前厂商 + 档位的模型名（供功能流程直接取）。
    static func model(_ tier: ModelTier) -> String { model(tier, for: provider) }

    /// 目标语言（PRD：当前仅"中文"，预留可配置）。
    static let targetLanguage = "中文"

    /// 润色温度（改写类）。
    static let polishTemperature = 0.5

    /// 请求超时（BUILD_SPEC §6：30s）。
    static let requestTimeout: TimeInterval = 30

    /// 全局快捷键展示串（实际注册见 Trigger/HotKey.swift）。
    static let hotKeyDisplay = "⌥⌘P"

    // MARK: - 悬浮条相对选区的偏移（用户拖动后记住）

    /// 悬浮条相对"选区锚点(鼠标抬起点)"的偏移。默认 (8,8) = 光标右上一点。
    static var barOffset: NSPoint {
        get {
            let d = UserDefaults.standard
            if d.object(forKey: "barOffsetX") == nil { return NSPoint(x: 8, y: 8) }
            return NSPoint(x: d.double(forKey: "barOffsetX"), y: d.double(forKey: "barOffsetY"))
        }
        set {
            UserDefaults.standard.set(Double(newValue.x), forKey: "barOffsetX")
            UserDefaults.standard.set(Double(newValue.y), forKey: "barOffsetY")
        }
    }

    // MARK: - 悬浮条排列（横/竖）

    private static let barVerticalKey = "barVertical"

    /// 悬浮条是否竖排。默认竖排。
    static var barVertical: Bool {
        get {
            if UserDefaults.standard.object(forKey: barVerticalKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: barVerticalKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: barVerticalKey) }
    }

    // MARK: - 每个功能的输出语言

    /// 可选语言。"跟随原文" = 与原文/对话相同的语言。
    static let languageOptions = ["跟随原文", "中文", "English", "日本語", "한국어"]

    static func outputLanguage(for feature: Feature) -> String {
        UserDefaults.standard.string(forKey: "lang." + feature.rawValue) ?? feature.defaultLanguage
    }

    static func setOutputLanguage(_ language: String, for feature: Feature) {
        UserDefaults.standard.set(language, forKey: "lang." + feature.rawValue)
    }

    // MARK: - 划词自动弹条（M1）

    private static let autoPopKey = "autoPopEnabled"

    /// 是否开启"划词自动弹出工具条"。默认开启；关掉则只靠快捷键触发。
    static var autoPopEnabled: Bool {
        get {
            // 未设置过时默认 true。
            if UserDefaults.standard.object(forKey: autoPopKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoPopKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoPopKey) }
    }
}
