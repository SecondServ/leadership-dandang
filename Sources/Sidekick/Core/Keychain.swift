import Foundation
import Security

/// API Key 存取（BUILD_SPEC §1/§6：只存 Keychain，不落 UserDefaults/明文）。
///
/// 安全：本类型不打印 Key 值；对外只暴露存/取/删。
enum Keychain {
    private static let service = "com.sidekick.mac"
    private static let account = "gemini-api-key"

    /// 保存/覆盖 API Key。空串等同删除。返回是否成功。
    @discardableResult
    static func setAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteAPIKey()
            return true
        }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // 先删旧，避免 duplicate item。
        SecItemDelete(base as CFDictionary)

        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// 读取 API Key；不存在返回 nil。
    static func apiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    /// 删除 API Key。
    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
