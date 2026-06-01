import SwiftUI
import Combine

enum TimePeriod: String, CaseIterable {
    case all = "全部"
    case week = "本周"
    case today = "今日"
}

enum AnalyticsTab: String, CaseIterable {
    case overview = "概览"
    case content = "内容"
    case events = "事件"
}

enum CreatorTab: String, CaseIterable {
    case myAds = "我的广告"
    case analytics = "数据看板"
}

/// 用户创建的广告
struct UserAd: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var description: String
    var sponsor: String
    var channel: String
    var cardType: String
    var tags: [String]
    var createdAt: Date
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var events: [AnalyticsEvent] = []
    @Published var enrichedEvents: [EnrichedEvent] = []
    @Published var stateChanges: [EnrichedEvent] = []
    @Published var impressions = 0
    @Published var clicks = 0
    @Published var likes = 0
    @Published var collects = 0
    @Published var shares = 0
    @Published var searches = 0
    @Published var tagClicks = 0
    @Published var ctr = 0.0
    @Published var channelBreakdown: [ChannelStats] = []
    @Published var topAds: [TopAdInfo] = []
    @Published var allAdsStats: [TopAdInfo] = []
    @Published var eventTypeBreakdown: [(type: AnalyticsEventType, count: Int)] = []
    @Published var selectedPeriod: TimePeriod = .all
    @Published var totalInteractions = 0
    @Published var selectedTab: AnalyticsTab = .overview
    @Published var selectedCreatorTab: CreatorTab = .myAds

    /// 用户投放的广告列表
    @Published var userAds: [UserAd] = []

    /// 新广告表单
    @Published var newAdTitle = ""
    @Published var newAdDescription = ""
    @Published var newAdSponsor = ""
    @Published var newAdChannel = "featured"
    @Published var newAdCardType = "bigImage"
    @Published var newAdTagsText = ""
    @Published var showUploadSheet = false

    private let service = AnalyticsService.shared
    private let db = DatabaseManager.shared

    private static let userAdsKey = "user_created_ads"

    var totalEvents: Int {
        impressions + clicks + likes + collects + shares + searches + tagClicks
    }

    /// 用户广告总数
    var userAdCount: Int { userAds.count }

    /// 用户广告获得的总曝光
    var userAdImpressions: Int {
        let adIds = Set(userAds.map(\.id))
        return events.filter { adIds.contains($0.adId ?? "") && $0.type == .impression }.count
    }

    /// 用户广告获得的总互动
    var userAdInteractions: Int {
        let adIds = Set(userAds.map(\.id))
        return events.filter { adIds.contains($0.adId ?? "")
            && ($0.type == .like || $0.type == .collect || $0.type == .share)
        }.count
    }

    /// 用户广告获得的总点击
    var userAdClicks: Int {
        let adIds = Set(userAds.map(\.id))
        return events.filter { adIds.contains($0.adId ?? "") && $0.type == .click }.count
    }

    init() {
        loadUserAds()
    }

    func refresh() {
        impressions = service.impressionCount()
        clicks = service.clickCount()
        likes = service.likeCount()
        collects = service.collectCount()
        shares = service.shareCount()
        searches = service.searchCount()
        tagClicks = service.tagClickCount()
        ctr = service.ctr()
        totalInteractions = likes + collects + shares
        channelBreakdown = service.channelBreakdown()
        topAds = service.topInteractedAds()
        allAdsStats = service.allAdsStats()
        eventTypeBreakdown = service.eventTypeBreakdown()
        enrichedEvents = service.enrichedEvents()
        stateChanges = service.stateChangeLog()
    }

    // MARK: - User Ads CRUD

    func loadUserAds() {
        guard let data = UserDefaults.standard.data(forKey: Self.userAdsKey),
              let ads = try? JSONDecoder().decode([UserAd].self, from: data)
        else { return }
        userAds = ads
    }

    func uploadAd() {
        let tags = newAdTagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let ad = UserAd(
            title: newAdTitle.trimmingCharacters(in: .whitespaces),
            description: newAdDescription.trimmingCharacters(in: .whitespaces),
            sponsor: newAdSponsor.trimmingCharacters(in: .whitespaces),
            channel: newAdChannel,
            cardType: newAdCardType,
            tags: tags,
            createdAt: Date()
        )

        userAds.insert(ad, at: 0)
        saveUserAds()

        // 同时插入数据库以便分析追踪
        let adItem = AdItem(
            id: ad.id,
            title: ad.title,
            description: ad.description,
            imageURL: "",
            videoURL: nil,
            cardType: AdCardType(rawValue: ad.cardType) ?? .bigImage,
            channel: Channel(rawValue: ad.channel) ?? .featured,
            tags: ad.tags.enumerated().map { i, name in
                AITag(id: "user_\(ad.id)_\(i)", name: name, category: .category)
            },
            aiSummary: String(ad.description.prefix(80)),
            sponsor: ad.sponsor
        )
        db.insertAd(adItem)

        // 重置表单
        newAdTitle = ""
        newAdDescription = ""
        newAdSponsor = ""
        newAdTagsText = ""
        showUploadSheet = false
    }

    func deleteUserAd(_ ad: UserAd) {
        userAds.removeAll { $0.id == ad.id }
        saveUserAds()
    }

    private func saveUserAds() {
        guard let data = try? JSONEncoder().encode(userAds) else { return }
        UserDefaults.standard.set(data, forKey: Self.userAdsKey)
    }

    /// 用户广告的统计摘要
    func statsForUserAd(_ ad: UserAd) -> (impressions: Int, clicks: Int, likes: Int, collects: Int, shares: Int) {
        let related = events.filter { $0.adId == ad.id }
        return (
            impressions: related.filter { $0.type == .impression }.count,
            clicks: related.filter { $0.type == .click }.count,
            likes: related.filter { $0.type == .like }.count,
            collects: related.filter { $0.type == .collect }.count,
            shares: related.filter { $0.type == .share }.count
        )
    }

    var channelOptions: [(value: String, label: String)] {
        Channel.allCases.map { ($0.rawValue, $0.displayName) }
    }

    var cardTypeOptions: [(value: String, label: String)] {
        [("bigImage", "大图卡片"), ("smallImage", "小图卡片"), ("video", "视频卡片")]
    }
}
