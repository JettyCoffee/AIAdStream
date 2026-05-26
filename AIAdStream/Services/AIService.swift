import Foundation

final class AIService {
    private let persistence = DataPersistence.shared

    func generateSummary(for ad: AdItem) async -> String? {
        if let cached = persistence.loadAICache()[ad.id]?.summary {
            return cached
        }
        let summary = buildFallbackSummary(for: ad)
        cacheResult(adId: ad.id, summary: summary, tags: nil)
        return summary
    }

    func generateTags(for ad: AdItem) async -> [AITag] {
        if let cached = persistence.loadAICache()[ad.id]?.tags, !cached.isEmpty {
            return cached
        }
        let tags = buildFallbackTags(for: ad)
        cacheResult(adId: ad.id, summary: nil, tags: tags)
        return tags
    }

    func conversationalSearch(query: String, ads: [AdItem]) async -> [AdItem] {
        let lowercased = query.lowercased()
        let keywords = extractKeywords(from: query)
        let scored = ads.map { ad -> (AdItem, Int) in
            var score = 0
            let text = "\(ad.title) \(ad.description) \(ad.sponsor)".lowercased()
            for kw in keywords {
                if text.contains(kw) { score += 10 }
            }
            for kw in keywords {
                if ad.title.lowercased().contains(kw) { score += 15 }
            }
            for tag in ad.tags {
                if keywords.contains(where: { tag.name.contains($0) || $0.contains(tag.name) }) {
                    score += 12
                }
            }
            if lowercased.contains("视频") && ad.cardType == .video { score += 8 }
            if lowercased.contains("图片") && ad.cardType != .video { score += 5 }
            return (ad, score)
        }
        return scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { $0.0 }
    }

    private func buildFallbackSummary(for ad: AdItem) -> String {
        "「\(ad.sponsor)」推出的\(ad.title)，\(ad.description.prefix(30))...了解更多请点击详情。"
    }

    private func buildFallbackTags(for ad: AdItem) -> [AITag] {
        var tags: [AITag] = []
        let text = "\(ad.title) \(ad.description)".lowercased()
        let categoryRules: [(String, TagCategory)] = [
            ("运动", .category), ("鞋", .category), ("数码", .category),
            ("美妆", .category), ("食品", .category), ("汽车", .category),
            ("服装", .category), ("护肤", .category), ("餐饮", .category),
            ("家电", .category), ("玩具", .category),
        ]
        for (kw, cat) in categoryRules {
            if text.contains(kw) && !tags.contains(where: { $0.name == kw }) {
                tags.append(AITag(id: "tag_\(tags.count)", name: kw, category: cat))
            }
        }
        let styleRules: [(String, TagCategory)] = [
            ("简约", .style), ("复古", .style), ("科技", .style),
            ("时尚", .style), ("文艺", .style),
        ]
        for (kw, cat) in styleRules {
            if text.contains(kw) && !tags.contains(where: { $0.name == kw }) {
                tags.append(AITag(id: "tag_\(tags.count)", name: kw, category: cat))
            }
        }
        let audienceRules: [(String, TagCategory)] = [
            ("学生党", .audience), ("上班族", .audience), ("运动爱好者", .audience),
            ("宝妈", .audience),
        ]
        for (kw, cat) in audienceRules {
            if text.contains(kw) && !tags.contains(where: { $0.name == kw }) {
                tags.append(AITag(id: "tag_\(tags.count)", name: kw, category: cat))
            }
        }
        let sceneRules: [(String, TagCategory)] = [
            ("通勤", .scene), ("健身", .scene), ("送礼", .scene),
            ("聚会", .scene), ("居家", .scene),
        ]
        for (kw, cat) in sceneRules {
            if text.contains(kw) && !tags.contains(where: { $0.name == kw }) {
                tags.append(AITag(id: "tag_\(tags.count)", name: kw, category: cat))
            }
        }
        if tags.isEmpty {
            tags = [
                AITag(id: "tag_0", name: "热门", category: .category),
                AITag(id: "tag_1", name: "推荐", category: .style),
            ]
        }
        return tags
    }

    private func extractKeywords(from query: String) -> [String] {
        let stopWords = ["的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都", "一", "一个",
                         "想", "看", "要", "找", "推荐", "适合", "有没有", "哪些", "什么", "可以"]
        return query
            .replacingOccurrences(of: ",|，|、|。|！|？| ", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 1 && !stopWords.contains($0) }
    }

    private func cacheResult(adId: String, summary: String?, tags: [AITag]?) {
        var cache = persistence.loadAICache()
        let existing = cache[adId] ?? AICacheEntry(summary: nil, tags: [])
        cache[adId] = AICacheEntry(
            summary: summary ?? existing.summary,
            tags: tags ?? existing.tags
        )
        persistence.saveAICache(cache)
    }
}
