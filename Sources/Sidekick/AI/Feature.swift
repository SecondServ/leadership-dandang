import Foundation

/// 7 个功能枚举与元数据（PRD 第 3 节 / BUILD_SPEC §6、§8）。
///
/// 纯逻辑，仅依赖 Foundation，不碰 AppKit —— 便于将来 Windows 原生版照抄。
enum Feature: String, CaseIterable {
    case plainSpeak    // 1 让 ta 说人话
    case whoSaidWhat   // 2 叽里咕噜说啥呢（原「ta 们在讨论啥」）
    case polish        // 3 润色
    case reply         // 4 帮我回复（交互式，Batch B）
    case yinyang       // 5 帮我阴阳 ta
    case relevance     // 6 关我毛事
    case presence      // 7 刷存在感

    /// 全称（结果卡片标题、二级菜单项、按钮都用它）。
    var displayName: String {
        switch self {
        case .plainSpeak:  return "让ta说人话"
        case .whoSaidWhat: return "叽里咕噜说啥呢"
        case .polish:      return "体面一点"
        case .reply:       return "打发丫"
        case .yinyang:     return "帮我阴阳ta"   // 已并入「打发丫」的"阴阳"立场，不再单独上工具条
        case .relevance:   return "关我毛事"
        case .presence:    return "刷存在感"
        }
    }

    // MARK: - 模型 / 速度

    /// 模型档（BUILD_SPEC §6）。
    var model: String {
        switch self {
        case .relevance, .presence: return Settings.strongModel
        default:                    return Settings.fastModel
        }
    }

    /// 采样温度（BUILD_SPEC §6）。
    var temperature: Double {
        switch self {
        case .plainSpeak, .whoSaidWhat, .relevance: return 0.2
        case .polish, .reply:                       return 0.5
        case .yinyang, .presence:                   return 0.7
        }
    }

    /// thinking 预算：0 = 关闭思考（更快，简单任务用）；nil = 用模型默认（保留思考，推理类用）。
    var thinkingBudget: Int? {
        switch self {
        case .relevance, .presence: return nil   // 需要推理，保留 thinking
        default:                    return 0     // 翻译/改写/总结，关掉更快
        }
    }

    // MARK: - Profile / 交互 / 展示

    var requiresProfile: Bool { self == .relevance }
    var usesProfile: Bool { self == .relevance || self == .presence }
    var isInteractive: Bool { self == .reply }

    var supportsReplace: Bool {
        switch self {
        case .polish, .reply, .presence: return true
        default:                         return false
        }
    }

    var riskNote: String? {
        self == .yinyang ? "发送前请自行判断风险" : nil
    }

    var systemExtra: String? {
        self == .yinyang
            ? "输出必须表面礼貌、职场可发送、不使用脏话或人身攻击，讽刺要\"可辩解的得体\"。"
            : nil
    }

    /// 输出是否含「〔潜台词〕」小字附注（功能 1：说人话）。
    var producesSubtext: Bool { self == .plainSpeak }

    // MARK: - 输出语言

    /// 默认输出语言：翻译/分析类默认"中文"；改写/生成类默认"跟随原文"。
    var defaultLanguage: String {
        switch self {
        case .plainSpeak, .whoSaidWhat, .relevance: return "中文"
        default:                                     return "跟随原文"
        }
    }
}

/// 二级菜单里的一项：某功能（可带变体，如润色语气）。
struct BarAction {
    let title: String
    let feature: Feature
    let variant: String?   // 润色语气：正式/中性/亲切；其它为 nil

    init(_ title: String, _ feature: Feature, variant: String? = nil) {
        self.title = title
        self.feature = feature
        self.variant = variant
    }
}

/// 悬浮工具条上的一项：单个功能，或一个含二级菜单的分组。
enum BarItem {
    case single(Feature)
    case group(title: String, actions: [BarAction])

    /// 工具条布局（顺序即展示顺序）。
    /// - 「BB啥呢」：叽里咕噜说啥呢 + 关我毛事（两个不同功能）。
    /// - 「润色」：正式 / 中性 / 亲切（同一功能的三档语气）。
    static var all: [BarItem] {
        [
            .single(.plainSpeak),
            .group(title: "BB啥呢", actions: [
                BarAction("叽里咕噜说啥呢", .whoSaidWhat),
                BarAction("关我毛事", .relevance)
            ]),
            .group(title: "体面一点", actions: [
                BarAction("正式", .polish, variant: "正式"),
                BarAction("幽默", .polish, variant: "幽默"),
                BarAction("口语化", .polish, variant: "口语化"),
                BarAction("委婉", .polish, variant: "委婉"),
                BarAction("有条理", .polish, variant: "有条理")
            ]),
            .single(.presence),
            // 打发丫：立场进二级菜单；「阴阳」并入其中，不再单独上工具条。
            .group(title: "打发丫", actions: [
                BarAction("同意", .reply, variant: "同意"),
                BarAction("婉拒", .reply, variant: "婉拒"),
                BarAction("捧杀", .reply, variant: "捧杀"),
                BarAction("质疑", .reply, variant: "质疑"),
                BarAction("共情", .reply, variant: "共情"),
                BarAction("甩锅", .reply, variant: "甩锅"),
                BarAction("阴阳", .reply, variant: "阴阳")
            ])
        ]
    }
}
