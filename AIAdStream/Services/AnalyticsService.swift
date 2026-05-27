import Foundation

enum AnalyticsEventType: String, Codable, CaseIterable {
    case impression
    case click
    case like
    case collect
    case share
    case search
    case tagClick
    case stateChange
}

struct AnalyticsEvent: Identifiable, Codable {
    let id: String
    let type: AnalyticsEventType
    let adId: String?
    let channel: String?
    let timestamp: Date
    let metadata: String?
}

struct AdContext: Codable {
    let adTitle: String
    let adSponsor: String
    let cardType: String
}

struct StateChangeInfo: Codable {
    let field: String
    let from: String
    let to: String
}

struct EnrichedEvent: Identifiable {
    let id: String
    let type: AnalyticsEventType
    let adId: String?
    let adTitle: String?
    let adSponsor: String?
    let channel: String?
    let timestamp: Date
    let metadata: String?
    let displayText: String
    let stateChange: StateChangeInfo?
}

struct ChannelStats {
    let channel: String
    let impressions: Int
    let clicks: Int
    let likes: Int
    let collects: Int
    let shares: Int
    let ctr: Double
}

struct TopAdInfo {
    let adId: String
    let adTitle: String
    let adSponsor: String
    let count: Int
    let breakdown: [AnalyticsEventType: Int]
}

final class AnalyticsService {
    static let shared = AnalyticsService()

    private let db = DatabaseManager.shared

    private init() {}

    func track(_ type: AnalyticsEventType, adId: String? = nil, channel: Channel? = nil, metadata: String? = nil) {
        let event = AnalyticsEvent(
            id: UUID().uuidString,
            type: type,
            adId: adId,
            channel: channel?.rawValue,
            timestamp: Date(),
            metadata: metadata
        )
        db.insertAnalyticsEvent(event)
    }

    func trackWithAdContext(_ type: AnalyticsEventType, ad: AdItem, channel: Channel? = nil, extra: String? = nil) {
        let context = AdContext(adTitle: ad.title, adSponsor: ad.sponsor, cardType: ad.cardType.rawValue)
        var meta = ""
        if let data = try? JSONEncoder().encode(context),
           let json = String(data: data, encoding: .utf8) {
            meta = json
        }
        if let extra = extra {
            meta = meta.isEmpty ? extra : "\(meta)|\(extra)"
        }
        track(type, adId: ad.id, channel: channel ?? ad.channel, metadata: meta)
    }

    func trackStateChange(ad: AdItem, field: String, from: String, to: String) {
        let info = StateChangeInfo(field: field, from: from, to: to)
        let context = AdContext(adTitle: ad.title, adSponsor: ad.sponsor, cardType: ad.cardType.rawValue)
        var meta: [String: String] = [:]
        if let contextData = try? JSONEncoder().encode(context),
           let contextJSON = String(data: contextData, encoding: .utf8) {
            meta["context"] = contextJSON
        }
        if let infoData = try? JSONEncoder().encode(info),
           let infoJSON = String(data: infoData, encoding: .utf8) {
            meta["stateChange"] = infoJSON
        }
        if let combined = try? JSONEncoder().encode(meta),
           let combinedJSON = String(data: combined, encoding: .utf8) {
            track(.stateChange, adId: ad.id, channel: ad.channel, metadata: combinedJSON)
        }
    }

    // MARK: - Aggregation

    func allEvents() -> [AnalyticsEvent] {
        db.fetchAnalyticsEvents()
    }

    func impressionCount() -> Int {
        allEvents().filter { $0.type == .impression }.count
    }

    func clickCount() -> Int {
        allEvents().filter { $0.type == .click }.count
    }

    func likeCount() -> Int {
        allEvents().filter { $0.type == .like }.count
    }

    func collectCount() -> Int {
        allEvents().filter { $0.type == .collect }.count
    }

    func shareCount() -> Int {
        allEvents().filter { $0.type == .share }.count
    }

    func searchCount() -> Int {
        allEvents().filter { $0.type == .search }.count
    }

    func tagClickCount() -> Int {
        allEvents().filter { $0.type == .tagClick }.count
    }

    func ctr() -> Double {
        let impressions = impressionCount()
        guard impressions > 0 else { return 0 }
        return Double(clickCount()) / Double(impressions) * 100
    }

    func eventTypeBreakdown() -> [(type: AnalyticsEventType, count: Int)] {
        let events = allEvents()
        return AnalyticsEventType.allCases.map { type in
            (type, events.filter { $0.type == type }.count)
        }.sorted { $0.count > $1.count }
    }

    func channelBreakdown() -> [ChannelStats] {
        let events = allEvents()
        let grouped = Dictionary(grouping: events.filter { $0.channel != nil }) { $0.channel! }
        return grouped.map { channel, evts in
            let imps = evts.filter { $0.type == .impression }.count
            let clks = evts.filter { $0.type == .click }.count
            let lks = evts.filter { $0.type == .like }.count
            let cols = evts.filter { $0.type == .collect }.count
            let shrs = evts.filter { $0.type == .share }.count
            let ctrVal = imps > 0 ? Double(clks) / Double(imps) * 100 : 0
            return ChannelStats(channel: channel, impressions: imps, clicks: clks, likes: lks, collects: cols, shares: shrs, ctr: ctrVal)
        }.sorted { $0.impressions > $1.impressions }
    }

    func topInteractedAds(limit: Int = 5) -> [TopAdInfo] {
        let events = allEvents()
        let adEvents = events.filter { $0.adId != nil }
        let grouped = Dictionary(grouping: adEvents) { $0.adId! }
        return grouped.map { adId, evts in
            let breakdown = Dictionary(grouping: evts) { $0.type }.mapValues { $0.count }
            let context = parseAdContext(from: evts.first?.metadata) ?? (title: adId, sponsor: "")
            return TopAdInfo(adId: adId, adTitle: context.title, adSponsor: context.sponsor, count: evts.count, breakdown: breakdown)
        }
        .sorted { $0.count > $1.count }
        .prefix(limit)
        .map { $0 }
    }

    func enrichedEvents(limit: Int = 50) -> [EnrichedEvent] {
        let events = allEvents().prefix(limit)
        return events.map { event in
            let context = parseAdContext(from: event.metadata)
            let stateChange = parseStateChange(from: event.metadata)
            return EnrichedEvent(
                id: event.id,
                type: event.type,
                adId: event.adId,
                adTitle: context?.title,
                adSponsor: context?.sponsor,
                channel: event.channel,
                timestamp: event.timestamp,
                metadata: event.metadata,
                displayText: makeDisplayText(event: event, adTitle: context?.title, stateChange: stateChange),
                stateChange: stateChange
            )
        }
    }

    func stateChangeLog(limit: Int = 30) -> [EnrichedEvent] {
        enrichedEvents(limit: limit).filter { $0.type == .stateChange }
    }

    // MARK: - Helpers

    private func parseAdContext(from metadata: String?) -> (title: String, sponsor: String)? {
        guard let meta = metadata else { return nil }
        let contextJSON: String
        if meta.contains("\"context\"") {
            guard let data = meta.data(using: .utf8),
                  let wrapper = try? JSONDecoder().decode([String: String].self, from: data),
                  let ctx = wrapper["context"] else { return nil }
            contextJSON = ctx
        } else if meta.contains("\"adTitle\"") {
            contextJSON = meta
        } else {
            return nil
        }
        guard let data = contextJSON.data(using: .utf8),
              let context = try? JSONDecoder().decode(AdContext.self, from: data) else { return nil }
        return (context.adTitle, context.adSponsor)
    }

    private func parseStateChange(from metadata: String?) -> StateChangeInfo? {
        guard let meta = metadata, meta.contains("\"stateChange\"") else { return nil }
        guard let data = meta.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode([String: String].self, from: data),
              let scJSON = wrapper["stateChange"],
              let scData = scJSON.data(using: .utf8),
              let info = try? JSONDecoder().decode(StateChangeInfo.self, from: scData) else { return nil }
        return info
    }

    private func makeDisplayText(event: AnalyticsEvent, adTitle: String?, stateChange: StateChangeInfo?) -> String {
        switch event.type {
        case .impression:
            if let title = adTitle { return "浏览了「\(title)」" }
            return "浏览了广告 \(event.adId ?? "")"
        case .click:
            if let title = adTitle { return "点击了「\(title)」" }
            return "点击了广告 \(event.adId ?? "")"
        case .like:
            if let title = adTitle { return "点赞了「\(title)」" }
            return "点赞了广告 \(event.adId ?? "")"
        case .collect:
            if let title = adTitle { return "收藏了「\(title)」" }
            return "收藏了广告 \(event.adId ?? "")"
        case .share:
            if let title = adTitle { return "分享了「\(title)」" }
            return "分享了广告 \(event.adId ?? "")"
        case .search:
            return "搜索了「\(event.metadata ?? "")」"
        case .tagClick:
            if let title = adTitle { return "点击了标签 \(event.metadata ?? "") · 「\(title)」" }
            return "点击了标签 \(event.metadata ?? "")"
        case .stateChange:
            if let sc = stateChange, let title = adTitle {
                let fieldName = stateChangeFieldName(sc.field)
                return "状态变更: 「\(title)」\(fieldName) \(sc.from) → \(sc.to)"
            }
            return "状态变更"
        }
    }

    private func stateChangeFieldName(_ field: String) -> String {
        switch field {
        case "isLiked": return "点赞"
        case "isCollected": return "收藏"
        case "likeCount": return "点赞数"
        case "shareCount": return "分享数"
        default: return field
        }
    }
}
