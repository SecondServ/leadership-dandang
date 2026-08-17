import Foundation

/// 调 Gemini `generateContent`（BUILD_SPEC §6）。错误类型见 AIError（AIProvider.swift）。
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
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
        do {
            let data = try await post(system: system, user: user, temperature: temperature, thinkingBudget: thinkingBudget)
            return try Self.extractText(from: data)
        } catch AIError.http(let code, _) where code == 400 && thinkingBudget != nil {
            // 某些模型不允许关闭思考（thinkingBudget=0 → 400）。去掉 thinkingConfig 再试一次。
            let data = try await post(system: system, user: user, temperature: temperature, thinkingBudget: nil)
            return try Self.extractText(from: data)
        }
    }

    private func post(system: String, user: String, temperature: Double, thinkingBudget: Int?) async throws -> Data {
        var comps = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        )
        comps?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps?.url else { throw AIError.network("URL 构造失败") }

        var generationConfig: [String: Any] = [
            "temperature": temperature,
            "maxOutputTokens": 2048
        ]
        if let thinkingBudget {
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
        return try await AIHTTP.send(req)
    }

    /// 列出该 Key 可用、且支持 `generateContent` 的模型名（去掉 "models/" 前缀，已排序）。
    static func listModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        var comps = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
        comps?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps?.url else { throw AIError.network("URL 构造失败") }

        var req = URLRequest(url: url)
        req.timeoutInterval = 20

        let data = try await AIHTTP.send(req)
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw AIError.decoding
        }
        let names = models.compactMap { model -> String? in
            guard let name = model["name"] as? String else { return nil }
            let methods = model["supportedGenerationMethods"] as? [String] ?? []
            guard methods.contains("generateContent") else { return nil }
            return name.replacingOccurrences(of: "models/", with: "")
        }
        return names.sorted()
    }

    /// 解析 `generateContent` 响应，取第一段候选文本并 trim。
    static func extractText(from data: Data) throws -> String {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AIError.decoding
        }
        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIError.emptyResponse
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyResponse }
        return trimmed
    }
}
