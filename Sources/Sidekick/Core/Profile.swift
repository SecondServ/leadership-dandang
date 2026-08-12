import Foundation

/// 用户 Profile（PRD §6）。供功能 6「关我毛事？」/ 7「刷存在感」组装 prompt 用。
///
/// 存在 `UserDefaults`（非敏感信息，不涉及 Key）。纯 Foundation。
struct Profile: Codable, Equatable {
    var name = ""       // 姓名 / 昵称
    var role = ""       // 公司角色、职级
    var team = ""       // 所在团队、主要职责
    var focus = ""      // 关注事项 / 负责的项目
    var languages = ""  // 语言偏好

    var isEmpty: Bool {
        [name, role, team, focus, languages]
            .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// 注入 prompt 的 `{{PROFILE}}` 文本。
    var promptDescription: String {
        var lines: [String] = []
        func add(_ label: String, _ value: String) {
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { lines.append("- \(label)：\(v)") }
        }
        add("姓名/昵称", name)
        add("角色/职级", role)
        add("团队/职责", team)
        add("关注事项/负责项目", focus)
        add("语言偏好", languages)
        return lines.isEmpty ? "（用户未填写个人资料）" : lines.joined(separator: "\n")
    }

    // MARK: - 存取

    private static let key = "profile.v1"

    static var current: Profile { load() }

    static func load() -> Profile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            return Profile()
        }
        return profile
    }

    static func save(_ profile: Profile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
