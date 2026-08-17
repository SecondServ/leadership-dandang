import Foundation

/// Anthropic Messages API 客户端（POST /v1/messages）。
///
/// 纯 Foundation，不依赖 AppKit。不发送 temperature（Claude 5 系拒绝非默认温度，会 400）。
/// 安全：任何地方不打印 Key 或用户文本。
struct AnthropicClient {
    let apiKey: String
    let model: String
    let timeout: TimeInterval = Settings.requestTimeout

    private let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let modelsURL = URL(string: "https://api.anthropic.com/v1/models")!
    private let version = "2023-06-01"

    func generate(system: String, user: String) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]

        var req = URLRequest(url: messagesURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue(version, forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = timeout
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await AIHTTP.send(req)
        return try Self.extractText(from: data)
    }

    static func listModels(apiKey: String) async throws -> [String] {
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 20

        let data = try await AIHTTP.send(req)
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let arr = json["data"] as? [[String: Any]] else {
            throw AIError.decoding
        }
        return arr.compactMap { $0["id"] as? String }.sorted()
    }

    /// 解析 Messages 响应：content[] 中所有 text 块拼接。
    static func extractText(from data: Data) throws -> String {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AIError.decoding
        }
        guard let content = json["content"] as? [[String: Any]] else {
            throw AIError.emptyResponse
        }
        let text = content.compactMap { block -> String? in
            (block["type"] as? String) == "text" ? block["text"] as? String : nil
        }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyResponse }
        return trimmed
    }
}
