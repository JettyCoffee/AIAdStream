import SwiftUI
import Combine

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var events: [AnalyticsEvent] = []
    @Published var impressions = 0
    @Published var clicks = 0
    @Published var ctr = 0.0
    @Published var channelBreakdown: [(channel: String, impressions: Int, clicks: Int)] = []
    @Published var topAds: [(adId: String, count: Int)] = []

    private let service = AnalyticsService.shared

    func refresh() {
        events = service.allEvents()
        impressions = service.impressionCount()
        clicks = service.clickCount()
        ctr = service.ctr()
        channelBreakdown = service.channelBreakdown()
        topAds = service.topInteractedAds()
    }
}
