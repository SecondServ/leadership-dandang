import Foundation

/// Gemini 调用可能出现的错误，带中文友好文案（BUILD_SPEC §6）。
enum GeminiError: Error, LocalizedError {
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
            return "还没有填 Gemini API Key。请到「设置」里填入付费 API Key。"
        case .rateLimited:
            return "请求过于频繁或额度超限（HTTP 429）。请稍后再试。"
        case .invalidKey(let code):
            return "API Key 可能无效或无权限（HTTP \(code)）。请到「设置」检查 Key。"
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

/// 调 Gemini `generateContent`（BUILD_SPEC §6）。
///
/// 纯 Foundation（URLSession async/await），**不依赖 AppKit** —— 逻辑可整块复用。
/// 安全：本类型任何地方都不打印 API Key 或用户文本。
struct GeminiClient {
    let model: String
    let apiKey: String
    let timeout: TimeInterval

    init(model: String, apiKey: String, timeout: TimeInterval = Settings.requestTimeout) {
        self.model = model
        self.apiKey = apiKey
        self.timeout = timeout
    }

    /// 通用调用：给定 system 指令 + user prompt + 温度，返回模型输出的纯文本。
    /// - Parameter thinkingBudget: 0 = 关闭思考（更快）；nil = 用模型默认（保留思考）。
    func generate(system: String, user: String, temperature: Double, thinkingBudget: Int? = nil) async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        // Endpoint：POST .../models/{model}:generateContent?key={API_KEY}
        var comps = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )
        comps?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps?.url else { throw GeminiError.network("URL 构造失败") }

        var generationConfig: [String: Any] = [
            "temperature": temperature,
            "maxOutputTokens": 2048
        ]
        if let thinkingBudget {
            // 2.5 系为思考模型；budget=0 关闭思考以提速（简单任务）。
            generationConfig["thinkingConfig"] = ["thinkingBudget": thinkingBudget]
        }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": user]]]],
            "generationConfig": generationConfig
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let urlErr as URLError {
            if urlErr.code == .timedOut { throw GeminiError.timeout }
            throw GeminiError.network(urlErr.localizedDescription)
        } catch {
            throw GeminiError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.network("无效的服务器响应")
        }
        switch http.statusCode {
        case 200:
            break
        case 429:
            throw GeminiError.rateLimited
        case 400, 401, 403:
            throw GeminiError.invalidKey(http.statusCode)
        default:
            throw GeminiError.http(http.statusCode, Self.apiErrorMessage(from: data))
        }

        return try Self.extractText(from: data)
    }

    /// 列出该 Key 可用、且支持 `generateContent` 的模型名（去掉 "models/" 前缀，已排序）。
    static func listModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        var comps = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
        comps?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps?.url else { throw GeminiError.network("URL 构造失败") }

        var req = URLRequest(url: url)
        req.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let urlErr as URLError {
            if urlErr.code == .timedOut { throw GeminiError.timeout }
            throw GeminiError.network(urlErr.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw GeminiError.network("无效的服务器响应") }
        switch http.statusCode {
        case 200: break
        case 429: throw GeminiError.rateLimited
        case 400, 401, 403: throw GeminiError.invalidKey(http.statusCode)
        default: throw GeminiError.http(http.statusCode, apiErrorMessage(from: data))
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw GeminiError.decoding
        }
        let names = models.compactMap { model -> String? in
            guard let name = model["name"] as? String else { return nil }
            let methods = model["supportedGenerationMethods"] as? [String] ?? []
            guard methods.contains("generateContent") else { return nil }
            return name.replacingOccurrences(of: "models/", with: "")
        }
        return names.sorted()
    }

    /// 从错误响应里取 `error.message`（是 API 的错误说明，非用户内容），用于友好提示。
    static func apiErrorMessage(from data: Data) -> String? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    /// 解析 `generateContent` 响应，取第一段候选文本并 trim。
    static func extractText(from data: Data) throws -> String {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw GeminiError.decoding
        }
        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.emptyResponse
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiError.emptyResponse }
        return trimmed
    }
}
