import Foundation

final class AIService {
    private let db = DatabaseManager.shared

    func generateSummary(for ad: AdItem) async -> String? {
        let existingTags = db.tagsForAd(ad.id)
        if !existingTags.isEmpty, let summary = db.fetchAd(by: ad.id)?.aiSummary {
            return summary
        }
        return buildFallbackSummary(for: ad)
    }

    func generateTags(for ad: AdItem) async -> [AITag] {
        let existing = db.tagsForAd(ad.id)
        if !existing.isEmpty { return existing }
        return buildFallbackTags(for: ad)
    }

    func conversationalSearch(query: String, ads: [AdItem]) async -> [AdItem] {
        // 通过 Qwen 端侧模型（或 fallback 模糊匹配）将自然语言转为标签
        let tags = await QwenService.shared.extractTags(from: query)

        if !tags.isEmpty {
            // 标签管道检索：按匹配标签数降序返回
            let results = db.fetchAdsByTags(tags, channel: nil, limit: 20)
            if !results.isEmpty { return results }
        }

        // Fallback：关键词打分
        let keywords = extractKeywords(from: query)
        let lowercased = query.lowercased()
        let scored = ads.map { ad -> (AdItem, Int) in
            var score = 0
            let text = "\(ad.title) \(ad.description) \(ad.sponsor)".lowercased()
            for kw in keywords {
                if text.contains(kw) { score += 10 }
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
            ("家电", .category), ("玩具", .category), ("家居", .category),
            ("旅行", .category), ("娱乐", .category), ("文化", .category),
            ("零售", .category),
        ]
        for (kw, cat) in categoryRules {
            if text.contains(kw) && !tags.contains(where: { $0.name == kw }) {
                tags.append(AITag(id: "tag_\(tags.count)", name: kw, category: cat))
            }
        }
        let styleRules: [(String, TagCategory)] = [
            ("简约", .style), ("复古", .style), ("科技", .style),
            ("时尚", .style), ("文艺", .style), ("经典", .style),
            ("社交", .style),
        ]
        for (kw, cat) in styleRules {
            if text.contains(kw) && !tags.contains(where: { $0.name == kw }) {
                tags.append(AITag(id: "tag_\(tags.count)", name: kw, category: cat))
            }
        }
        let audienceRules: [(String, TagCategory)] = [
            ("学生党", .audience), ("上班族", .audience), ("运动爱好者", .audience),
            ("宝妈", .audience), ("都市丽人", .audience), ("摄影爱好者", .audience),
            ("户外爱好者", .audience), ("文艺青年", .audience), ("科技爱好者", .audience),
            ("潮流玩家", .audience), ("聚会达人", .audience), ("商务人士", .audience),
            ("家庭食客", .audience), ("旅行爱好者", .audience),
        ]
        for (kw, cat) in audienceRules {
            if text.contains(kw) && !tags.contains(where: { $0.name == kw }) {
                tags.append(AITag(id: "tag_\(tags.count)", name: kw, category: cat))
            }
        }
        let sceneRules: [(String, TagCategory)] = [
            ("通勤", .scene), ("健身", .scene), ("送礼", .scene),
            ("聚会", .scene), ("居家", .scene), ("旅行", .scene),
            ("购物", .scene), ("创作", .scene), ("户外", .scene),
            ("周末出行", .scene), ("社交", .scene),
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
}
