import Foundation

/// 各功能 Prompt 模板（BUILD_SPEC 第 7 节）。纯字符串逻辑，不依赖 AppKit。
///
/// 模板主体沿用 BUILD_SPEC §7；语言子句按每功能的输出语言设置动态生成。
enum Prompts {

    /// 通用 system 前缀（BUILD_SPEC §7 顶部，所有功能共用，原文照抄）。
    static let commonSystemPrefix =
        "你是一个帮助用户应对职场沟通的助手。只输出用户需要的结果本身，不要加前言、解释或\"以下是\"之类的话。结果必须可以直接复制使用。"

    static func systemPrompt(for feature: Feature) -> String {
        if let extra = feature.systemExtra {
            return commonSystemPrefix + " " + extra
        }
        return commonSystemPrefix
    }

    /// 组装 user prompt。`language` 为输出语言设置；`variant` 为变体（润色语气：正式/中性/亲切）。
    static func userPrompt(for feature: Feature, text: String, profile: Profile, language: String, variant: String? = nil) -> String {
        switch feature {
        case .plainSpeak:  return plainSpeak(text: text, into: intoLang(language))
        case .whoSaidWhat: return whoSaidWhat(text: text, into: intoLang(language))
        case .polish:      return polish(text: text,
                                         langLine: keepOrForce(language, keep: "保持和原文相同的语言（原文是什么语言就用什么语言输出）"),
                                         toneLine: polishToneLine(variant))
        case .yinyang:     return yinyang(text: text, langLine: keepOrForce(language, keep: "保持与原文相同语言"))
        case .relevance:   return relevance(text: text, into: intoLang(language), profile: profile.promptDescription)
        case .presence:    return presence(text: text, langLine: keepOrForce(language, keep: "保持与讨论相同语言"), profile: profile.promptDescription)
        case .reply:       return "" // Batch B
        }
    }

    /// 「打发丫」（原帮我回复，交互式）。自动分辨单条文字 / 多人对话；按立场 + 大致方向写回复。
    static func replyPrompt(text: String, intent: String, stance: String, langPolicy: String) -> String {
        let intentText = intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "（未填，请根据立场自行拟定合理方向）"
            : intent
        return """
        下面是我选中的内容。请先判断它是"一段单独的文字/消息"还是"多人对话"：
        - 如果是单独的一段文字/消息：针对它写一条回复。
        - 如果是多人对话：把整段当作上下文，针对【最后一个发言】写一条回话。

        请帮我写一条 professional、可直接发送的回复。
        - 我的回复大致方向：\(intentText)
        - 我的立场：\(stance)
          # 立场释义：
          # 同意=明确接受/配合；婉拒=礼貌拒绝并给台阶；
          # 捧杀=表面高度吹捧/抬高对方，暗里把对方架住，得体不露骨；
          # 质疑=有礼有据地提出疑问、挑战对方观点，不失专业；
          # 共情=先照顾对方情绪再表达；
          # 甩锅=得体地澄清这不在我职责范围/把责任归位，但不攻击他人；
          # 阴阳=表面礼貌、暗含讽刺/绵里藏针，"可辩解的得体"，不脏话不人身攻击
        - 语言：\(langPolicy)
        只输出回复正文。

        内容：
        \(text)
        """
    }

    /// 回复语言策略：跟随对话语言，或强制指定语言。
    static func replyLangPolicy(_ language: String) -> String {
        language == "跟随原文" ? "跟随对话语言" : "用\(language)输出（强制该语言，无论对话是什么语言）"
    }

    /// 立场为"阴阳"时给 system 附加的安全约束（最敏感，沿用 §7.5 的边界）。
    static func replySystemExtra(stance: String) -> String? {
        stance == "阴阳"
            ? "输出必须表面礼貌、职场可发送、不使用脏话或人身攻击，讽刺要\"可辩解的得体\"。"
            : nil
    }

    /// 「体面一点」风格档（正式/幽默/口语化/委婉）。默认（快捷键触发）为自然得体的商务语气。
    private static func polishToneLine(_ tone: String?) -> String {
        switch tone {
        case "正式":   return "更清晰、更专业，语气正式、庄重、书面化"
        case "幽默":   return "在更清晰的同时带点幽默/俏皮，轻松但不失分寸、职场可发送"
        case "口语化": return "更清晰、自然，用口语化、像平时说话的语气"
        case "委婉":   return "在更清晰的同时把话说得委婉、含蓄、给足面子，不生硬"
        case "有条理": return "把内容组织得更有条理、更有逻辑：可用先结论后细节的 top-down 结构，或用要点/bullet points 分条列出（保持原意，不新增信息）"
        default:       return "更清晰、更专业，语气自然得体"
        }
    }

    // MARK: - 语言子句

    /// 翻译/分析类：要"翻成/用"的目标语言。"跟随原文" → 与原文相同的语言。
    private static func intoLang(_ language: String) -> String {
        language == "跟随原文" ? "与原文相同的语言" : language
    }

    /// 改写/生成类：语言那一行。"跟随原文" → 用原模板文案；否则强制指定语言。
    private static func keepOrForce(_ language: String, keep: String) -> String {
        language == "跟随原文" ? keep : "用\(language)输出（把内容转成\(language)，其余原意不变）"
    }

    // MARK: - 模板

    /// 7.1 让 ta 说人话（多轮对话聚焦对方最后一句 + 附一行潜台词/吐槽）
    private static func plainSpeak(text: String, into lang: String) -> String {
        """
        把下面这段职场对话/消息翻译成\(lang)，要求：
        - 用大白话、口语化，像同事私下跟我解释一样
        - 尽量简洁，但不能漏掉任何关键信息（时间、数字、要求、结论都要保留）
        - 去掉客套、废话和行话
        - 如果这是一段多轮对话，重点解读【对方最后说的那句话】，其余内容只当作理解它的上下文

        先输出翻译后的大白话内容。
        然后另起一行，以「〔潜台词〕」开头，用一句话点出这句话可能在暗示什么、真正想表达什么，或者忍不住吐槽一下（可以毒舌、犀利，但不要人身攻击）。

        原文：
        \(text)
        """
    }

    /// 7.2 叽里咕噜说啥呢（原「ta 们在讨论啥」）
    private static func whoSaidWhat(text: String, into lang: String) -> String {
        """
        下面是一段可能有多个人参与的对话。请用\(lang)总结：
        1. 逐个发言人，列出「谁 → 表达了什么（观点/诉求/情绪）」
        2. 如果有已达成的结论或还没定的问题，最后用一行标注「结论/待决」
        保持忠实，不要替他们下判断。

        对话：
        \(text)
        """
    }

    /// 7.3 润色（语气档由 toneLine 决定）
    private static func polish(text: String, langLine: String, toneLine: String) -> String {
        """
        润色下面这段我要发出去的职场消息。要求：
        - \(langLine)
        - \(toneLine)
        - 不改变原意，不夸大，不添加我没说过的信息
        只输出润色后的版本。

        原文：
        \(text)
        """
    }

    /// 7.5 帮我阴阳 ta
    private static func yinyang(text: String, langLine: String) -> String {
        """
        针对下面这段内容，帮我写一条表面礼貌、但暗含讽刺/绵里藏针的回应。
        - 要在职场里"能发得出去"，让人挑不出明显毛病
        - 克制、绵里藏针，不要脏话、不要人身攻击
        - \(langLine)
        只输出回应正文。

        原文：
        \(text)
        """
    }

    /// 7.6 关我毛事
    private static func relevance(text: String, into lang: String, profile: String) -> String {
        """
        这是我在工作中看到的一段内容。我的个人资料如下：
        \(profile)

        请用\(lang)帮我判断，输出以下结构：
        1) 相关性：高 / 中 / 低 / 无关（一句话说明为什么）
        2) 关键事项：提到的任务、计划、事件（有就列，没有就写"无"）
        3) 对我的影响：直接或间接可能影响到我的地方
        4) 建议动作：如果需要我做点什么，列出来；不需要就写"暂无需行动"
        基于内容和我的资料判断，结论仅供参考。

        内容：
        \(text)
        """
    }

    /// 7.7 刷存在感
    private static func presence(text: String, langLine: String, profile: String) -> String {
        """
        下面是一段团队讨论。我的个人资料如下：
        \(profile)

        帮我组织一段有价值、专业的发言，让我能有质量地参与进去。要求：
        - 贴合上下文，给出真正有信息量的见解 / 方案 / 想法（不要空喊口号或客套）
        - 结构：1 段核心观点 + 2~3 条具体要点或建议
        - 语气专业、自信但不咄咄逼人，符合我的角色
        - \(langLine)
        只输出可发送的发言内容。

        讨论：
        \(text)
        """
    }
}
