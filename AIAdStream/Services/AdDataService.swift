import Foundation

final class AdDataService {
    private let db = DatabaseManager.shared

    func fetchAds(channel: Channel, page: Int, pageSize: Int, tagFilter: String? = nil) async throws -> AdPage {
        try await Task.sleep(nanoseconds: UInt64.random(in: 300_000_000...800_000_000))

        let offset = (page - 1) * pageSize
        let result = db.fetchAds(channel: channel.rawValue, offset: offset, limit: pageSize, tagFilter: tagFilter)
        let hasMore = offset + pageSize < result.total
        return AdPage(ads: result.ads, hasMore: hasMore)
    }

    func fetchAd(by id: String) -> AdItem? {
        db.fetchAd(by: id)
    }

    func allAds(for channel: Channel) -> [AdItem] {
        db.allAds(for: channel.rawValue)
    }

    func allAdsAcrossChannels() -> [AdItem] {
        var ads: [AdItem] = []
        for ch in Channel.allCases {
            ads.append(contentsOf: db.allAds(for: ch.rawValue))
        }
        return ads
    }

    func searchAds(query: String, channel: Channel?) -> [AdItem] {
        db.searchAds(query: query, channel: channel?.rawValue)
    }

    func allTags(for channel: Channel?) -> [String] {
        db.allTags(for: channel?.rawValue)
    }

    func allTagsWithCategory(for channel: Channel?) -> [AITag] {
        db.allTagsWithCategory(for: channel?.rawValue)
    }
}
