import Foundation

enum AnalyticsEventType: String, Codable {
    case impression
    case click
    case like
    case collect
    case share
    case search
    case tagClick
}

struct AnalyticsEvent: Identifiable, Codable {
    let id: String
    let type: AnalyticsEventType
    let adId: String?
    let channel: String?
    let timestamp: Date
    let metadata: String?
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

    func impressionCount() -> Int {
        allEvents().filter { $0.type == .impression }.count
    }

    func clickCount() -> Int {
        allEvents().filter { $0.type == .click }.count
    }

    func ctr() -> Double {
        let impressions = impressionCount()
        guard impressions > 0 else { return 0 }
        return Double(clickCount()) / Double(impressions) * 100
    }

    func channelBreakdown() -> [(channel: String, impressions: Int, clicks: Int)] {
        let events = allEvents()
        let grouped = Dictionary(grouping: events.filter { $0.channel != nil }) { $0.channel! }
        return grouped.map { channel, evts in
            let imps = evts.filter { $0.type == .impression }.count
            let clks = evts.filter { $0.type == .click }.count
            return (channel, imps, clks)
        }.sorted { $0.impressions > $1.impressions }
    }

    func topInteractedAds(limit: Int = 5) -> [(adId: String, count: Int)] {
        let events = allEvents()
        let adEvents = events.filter { $0.adId != nil }
        let grouped = Dictionary(grouping: adEvents) { $0.adId! }
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
    }

    func allEvents() -> [AnalyticsEvent] {
        db.fetchAnalyticsEvents()
    }
}
