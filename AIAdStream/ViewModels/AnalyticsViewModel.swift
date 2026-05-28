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

    private let service = AnalyticsService.shared

    var totalEvents: Int {
        impressions + clicks + likes + collects + shares + searches + tagClicks
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
}
