import Foundation

/// OpenAI 兼容 chat/completions 客户端。改 Base URL 即可用于 OpenAI / DeepSeek / xAI / Kimi 等。
///
/// 纯 Foundation，不依赖 AppKit。不发送 temperature（部分推理模型只接受默认温度）。
/// 安全：任何地方不打印 Key 或用户文本。
struct OpenAIClient {
    let baseURL: String
    let apiKey: String
    let model: String
    let timeout: TimeInterval = Settings.requestTimeout

    private func endpoint(_ path: String) throws -> URL {
        let base = baseURL.isEmpty ? "https://api.openai.com/v1" : baseURL
        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let url = URL(string: trimmed + path) else { throw AIError.network("URL 构造失败") }
        return url
    }

    func generate(system: String, user: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
        let url = try endpoint("/chat/completions")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "max_tokens": 2048
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = timeout
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await AIHTTP.send(req)
        return try Self.extractText(from: data)
    }

    static func listModels(baseURL: String, apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
        let base = baseURL.isEmpty ? "https://api.openai.com/v1" : baseURL
        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let url = URL(string: trimmed + "/models") else { throw AIError.network("URL 构造失败") }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20

        let data = try await AIHTTP.send(req)
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let arr = json["data"] as? [[String: Any]] else {
            throw AIError.decoding
        }
        return arr.compactMap { $0["id"] as? String }.sorted()
    }

    /// 解析 chat/completions：choices[0].message.content。
    static func extractText(from data: Data) throws -> String {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AIError.decoding
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.emptyResponse
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyResponse }
        return trimmed
    }
}
