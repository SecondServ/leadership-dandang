import Foundation

/// AI 调用错误（各家 provider 共用），带中文友好文案。
enum AIError: Error, LocalizedError {
    case missingAPIKey
    case rateLimited            // 429
    case invalidKey(Int)        // 400 / 401 / 403，通常是 Key 无效/无权限
    case http(Int, String?)     // 其它 HTTP 状态码（附 API 返回的原因，如模型不存在）
    case network(String)
    case timeout
    case emptyResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "还没有填这个厂商的 API Key。请到「设置」里填入。"
        case .rateLimited:
            return "请求过于频繁或额度超限（HTTP 429）。请稍后再试。"
        case .invalidKey(let code):
            return "API Key 可能无效或无权限（HTTP \(code)）。请到「设置」检查 Key（以及 Base URL / 模型名）。"
        case .http(let code, let reason):
            if let reason, !reason.isEmpty {
                return "请求失败（HTTP \(code)）：\(reason)"
            }
            return "请求失败（HTTP \(code)）。请稍后重试。"
        case .network(let msg):
            return "网络错误：\(msg)"
        case .timeout:
            return "请求超时（30s）。请检查网络后重试。"
        case .emptyResponse:
            return "模型没有返回内容。请重试。"
        case .decoding:
            return "无法解析模型返回的结果。请重试。"
        }
    }
}

/// 模型档位：快档（翻译/改写）/ 强档（分析/生成）。实际模型名由 Settings 按 provider 决定。
enum ModelTier {
    case fast, strong
}

/// 大模型厂商。OpenAI 兼容一档可覆盖 OpenAI / DeepSeek / xAI / Kimi 等（改 Base URL 即可）。
enum AIProvider: String, CaseIterable {
    case gemini
    case openai       // OpenAI 及所有"OpenAI 兼容"端点
    case anthropic

    var displayName: String {
        switch self {
        case .gemini:    return "Google Gemini"
        case .openai:    return "OpenAI 兼容"
        case .anthropic: return "Anthropic Claude"
        }
    }

    /// 是否需要 Base URL（OpenAI 兼容才需要，用来指向不同厂商）。
    var usesBaseURL: Bool { self == .openai }

    var defaultBaseURL: String { self == .openai ? "https://api.openai.com/v1" : "" }

    var defaultFastModel: String {
        switch self {
        case .gemini:    return "gemini-2.5-flash"
        case .openai:    return "gpt-4o-mini"
        case .anthropic: return "claude-haiku-4-5"
        }
    }

    var defaultStrongModel: String {
        switch self {
        case .gemini:    return "gemini-2.5-flash"
        case .openai:    return "gpt-4o"
        case .anthropic: return "claude-opus-5"
        }
    }

    /// 设置页里 Key 输入框的提示。
    var keyHint: String {
        switch self {
        case .gemini:    return "Gemini 付费 API Key（勿用免费 AI Studio Key）"
        case .openai:    return "OpenAI 兼容端点的 API Key（sk-…）"
        case .anthropic: return "Anthropic API Key（sk-ant-…）"
        }
    }
}

/// 统一分发到各家 provider 的客户端。纯 Foundation，不依赖 AppKit。
enum AIClient {
    /// 生成文本。temperature 仅 Gemini 使用（Claude 5 / 部分 OpenAI 模型不接受非默认温度）。
    static func generate(provider: AIProvider, apiKey: String, model: String, baseURL: String,
                         system: String, user: String, temperature: Double, thinkingBudget: Int?) async throws -> String {
        switch provider {
        case .gemini:
            return try await GeminiClient(model: model, apiKey: apiKey)
                .generate(system: system, user: user, temperature: temperature, thinkingBudget: thinkingBudget)
        case .openai:
            return try await OpenAIClient(baseURL: baseURL, apiKey: apiKey, model: model)
                .generate(system: system, user: user)
        case .anthropic:
            return try await AnthropicClient(apiKey: apiKey, model: model)
                .generate(system: system, user: user)
        }
    }

    static func listModels(provider: AIProvider, apiKey: String, baseURL: String) async throws -> [String] {
        switch provider {
        case .gemini:    return try await GeminiClient.listModels(apiKey: apiKey)
        case .openai:    return try await OpenAIClient.listModels(baseURL: baseURL, apiKey: apiKey)
        case .anthropic: return try await AnthropicClient.listModels(apiKey: apiKey)
        }
    }
}

// MARK: - 共享 HTTP 工具

enum AIHTTP {
    /// 检查响应状态码，抛出统一的 AIError。
    static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AIError.network("无效的服务器响应") }
        switch http.statusCode {
        case 200...299: return
        case 429:       throw AIError.rateLimited
        case 401, 403:  throw AIError.invalidKey(http.statusCode)   // 认证/权限
        // 400 是"请求有误"（模型名、参数不被支持等），不是 Key 问题 → 带上真实原因。
        default:        throw AIError.http(http.statusCode, apiErrorMessage(from: data))
        }
    }

    /// 从错误响应里取 `error.message`（Gemini / OpenAI / Anthropic 都用这个结构），非用户内容。
    static func apiErrorMessage(from data: Data) -> String? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let message = json["error"] as? String { return message }  // 有些兼容端点直接给字符串
        return nil
    }

    /// 发起请求并做统一错误映射。
    static func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlErr as URLError {
            if urlErr.code == .timedOut { throw AIError.timeout }
            throw AIError.network(urlErr.localizedDescription)
        } catch {
            throw AIError.network(error.localizedDescription)
        }
        try check(response, data)
        return data
    }
}
