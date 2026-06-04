import SwiftUI
import Combine

enum TimePeriod: String, CaseIterable {
    case today = "今日"
    case week = "本周"
    case month = "本月"
    case all = "全部"
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

/// 单日趋势数据点
struct DailyTrendPoint: Identifiable {
    var id: String { dateLabel }
    let dateLabel: String
    let date: Date
    let impressions: Int
    let clicks: Int
}

/// 渠道汇总统计
struct ChannelSummary: Identifiable {
    var id: String { channel }
    let channel: String
    let impressions: Int
    let clicks: Int
    let likes: Int
    let collects: Int
    let shares: Int
    var interactions: Int { likes + collects + shares }
    var ctr: Double {
        impressions > 0 ? Double(clicks) / Double(impressions) * 100 : 0
    }
    var engagementRate: Double {
        impressions > 0 ? Double(interactions) / Double(impressions) * 100 : 0
    }
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

    /// 展开的广告 ID（用于排行榜行展开）
    @Published var expandedTopAdId: String?

    private let service = AnalyticsService.shared
    private let db = DatabaseManager.shared

    private static let userAdsKey = "user_created_ads"

    var totalEvents: Int {
        impressions + clicks + likes + collects + shares + searches + tagClicks
    }

    // MARK: - 派生指标

    /// 互动率 = (点赞+收藏+分享) / 曝光
    var engagementRate: Double {
        guard impressions > 0 else { return 0 }
        return Double(totalInteractions) / Double(impressions) * 100
    }

    /// 用户广告总数
    var userAdCount: Int { userAds.count }

    /// 用户广告获得的总曝光
    var userAdImpressions: Int {
        let adIds = Set(userAds.map(\.id))
        return periodFilteredEvents.filter { adIds.contains($0.adId ?? "") && $0.type == .impression }.count
    }

    /// 用户广告获得的总互动
    var userAdInteractions: Int {
        let adIds = Set(userAds.map(\.id))
        return periodFilteredEvents.filter {
            adIds.contains($0.adId ?? "")
            && ($0.type == .like || $0.type == .collect || $0.type == .share)
        }.count
    }

    /// 用户广告获得的总点击
    var userAdClicks: Int {
        let adIds = Set(userAds.map(\.id))
        return periodFilteredEvents.filter { adIds.contains($0.adId ?? "") && $0.type == .click }.count
    }

    // MARK: - 按时间范围过滤的事件

    private var periodFilteredEvents: [AnalyticsEvent] {
        let all = events
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .today:
            return all.filter { calendar.isDateInToday($0.timestamp) }
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return all }
            return all.filter { $0.timestamp >= weekAgo }
        case .month:
            guard let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return all }
            return all.filter { $0.timestamp >= monthAgo }
        case .all:
            return all
        }
    }

    /// 每日趋势数据（用于折线/柱状图）
    var dailyTrend: [DailyTrendPoint] {
        let filtered = periodFilteredEvents
        let calendar = Calendar.current
        // 按日期分组
        let grouped = Dictionary(grouping: filtered) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        // 生成日期范围内的所有日期
        let allDates: [Date]
        switch selectedPeriod {
        case .today:
            allDates = [calendar.startOfDay(for: Date())]
        case .week:
            allDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
                .map { calendar.startOfDay(for: $0) }
                .sorted()
        case .month:
            allDates = (0..<30).compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
                .map { calendar.startOfDay(for: $0) }
                .sorted()
        case .all:
            let dates = grouped.keys.sorted()
            allDates = dates
        }

        let formatter = DateFormatter()
        formatter.dateFormat = selectedPeriod == .month || selectedPeriod == .all ? "MM/dd" : "EEE"

        return allDates.map { date in
            let dayEvents = grouped[date] ?? []
            return DailyTrendPoint(
                dateLabel: formatter.string(from: date),
                date: date,
                impressions: dayEvents.filter { $0.type == .impression }.count,
                clicks: dayEvents.filter { $0.type == .click }.count
            )
        }
    }

    /// 渠道汇总（带互动率）
    var channelSummaries: [ChannelSummary] {
        let filtered = periodFilteredEvents
        let grouped = Dictionary(grouping: filtered.filter { $0.channel != nil }) { $0.channel! }
        return grouped.map { channel, evts in
            ChannelSummary(
                channel: channel,
                impressions: evts.filter { $0.type == .impression }.count,
                clicks: evts.filter { $0.type == .click }.count,
                likes: evts.filter { $0.type == .like }.count,
                collects: evts.filter { $0.type == .collect }.count,
                shares: evts.filter { $0.type == .share }.count
            )
        }.sorted { $0.impressions > $1.impressions }
    }

    // MARK: - Init

    init() {
        loadUserAds()
    }

    func refresh() {
        events = service.allEvents()
        impressions = periodFilteredEvents.filter { $0.type == .impression }.count
        clicks = periodFilteredEvents.filter { $0.type == .click }.count
        likes = periodFilteredEvents.filter { $0.type == .like }.count
        collects = periodFilteredEvents.filter { $0.type == .collect }.count
        shares = periodFilteredEvents.filter { $0.type == .share }.count
        searches = periodFilteredEvents.filter { $0.type == .search }.count
        tagClicks = periodFilteredEvents.filter { $0.type == .tagClick }.count
        ctr = impressions > 0 ? Double(clicks) / Double(impressions) * 100 : 0
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

        NotificationCenter.default.post(name: .userAdDidChange, object: nil)
    }

    func deleteUserAd(_ ad: UserAd) {
        userAds.removeAll { $0.id == ad.id }
        saveUserAds()
        db.deleteAd(ad.id)
        NotificationCenter.default.post(name: .userAdDidChange, object: nil)
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

// MARK: - Notification Names

extension Notification.Name {
    /// 用户广告变更（上传 / 删除）
    static let userAdDidChange = Notification.Name("com.aiadstream.userAdDidChange")
}
