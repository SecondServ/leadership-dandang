import Foundation

/// 全局设置常量（BUILD_SPEC §6）。M0 先用常量，后续里程碑再做成可配置项。
enum Settings {
    // 模型档位（可在设置页选择，存 UserDefaults）。
    // 默认都用已验证可用的 flash，保证开箱不 404；用户刷新后可把强档换成 pro 等。
    static let defaultFastModel = "gemini-2.5-flash"
    static let defaultStrongModel = "gemini-2.5-flash"

    private static let fastModelKey = "fastModel"
    private static let strongModelKey = "strongModel"

    /// 快档模型（功能 1/2/3/4/5）。
    static var fastModel: String {
        get { UserDefaults.standard.string(forKey: fastModelKey) ?? defaultFastModel }
        set { UserDefaults.standard.set(newValue, forKey: fastModelKey) }
    }

    /// 强档模型（功能 6/7）。
    static var strongModel: String {
        get { UserDefaults.standard.string(forKey: strongModelKey) ?? defaultStrongModel }
        set { UserDefaults.standard.set(newValue, forKey: strongModelKey) }
    }

    /// 目标语言（PRD：当前仅"中文"，预留可配置）。
    static let targetLanguage = "中文"

    /// 润色温度（改写类）。
    static let polishTemperature = 0.5

    /// 请求超时（BUILD_SPEC §6：30s）。
    static let requestTimeout: TimeInterval = 30

    /// 全局快捷键展示串（实际注册见 Trigger/HotKey.swift）。
    static let hotKeyDisplay = "⌥⌘P"

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
