import Foundation
import Security

/// API Key 存取（只存 Keychain，不落 UserDefaults/明文）。按 provider 分别存放。
///
/// 安全：本类型不打印 Key 值；对外只暴露存/取/删。
enum Keychain {
    private static let service = "com.sidekick.mac"

    /// 各 provider 的 Keychain account。Gemini 沿用旧 account，避免已保存的 Key 丢失。
    private static func account(for provider: AIProvider) -> String {
        provider == .gemini ? "gemini-api-key" : "apikey.\(provider.rawValue)"
    }

    @discardableResult
    static func setAPIKey(_ key: String, for provider: AIProvider) -> Bool {
        let acct = account(for: provider)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteAPIKey(for: provider)
            return true
        }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acct
        ]
        SecItemDelete(base as CFDictionary)   // 先删旧，避免 duplicate item
        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func apiKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    static func deleteAPIKey(for provider: AIProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider)
        ]
        SecItemDelete(query as CFDictionary)
    }
}
