import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @AppStorage("deepseek_api_key") var apiKey = ""
    @AppStorage("auto_play_video") var autoPlayVideo = true

    /// 用户偏好的标签名称集合（JSON 数组存储）
    @AppStorage("favorite_tags") private var favoriteTagsData = "[]"

    /// 解析后的偏好标签
    var favoriteTags: [String] {
        get {
            guard let data = favoriteTagsData.data(using: .utf8),
                  let tags = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return tags
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                favoriteTagsData = String(data: data, encoding: .utf8) ?? "[]"
            }
        }
    }

    /// 所有可用标签（跨频道去重）
    var allAvailableTags: [AITag] {
        DatabaseManager.shared.allTagsWithCategory(for: nil)
    }

    /// 按分类分组的标签
    var tagsGroupedByCategory: [(category: TagCategory, tags: [AITag])] {
        let grouped = Dictionary(grouping: allAvailableTags) { $0.category }
        return TagCategory.allCases.compactMap { category in
            let tags = grouped[category] ?? []
            return tags.isEmpty ? nil : (category, tags)
        }
    }

    func toggleFavoriteTag(_ tagName: String) {
        var current = favoriteTags
        if let idx = current.firstIndex(of: tagName) {
            current.remove(at: idx)
        } else {
            current.append(tagName)
        }
        favoriteTags = current
    }

    func isFavoriteTag(_ tagName: String) -> Bool {
        favoriteTags.contains(tagName)
    }

    /// 是否为有效的 API Key（非空且格式大致正确）
    var isKeyValid: Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("sk-") && trimmed.count > 20
    }

    /// 标签偏好数量
    var favoriteTagCount: Int {
        favoriteTags.count
    }
}
