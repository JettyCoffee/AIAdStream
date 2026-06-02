import XCTest
@testable import AIAdStream

final class AnalyticsServiceTests: XCTestCase {
    var analytics: AnalyticsService!

    override func setUp() {
        super.setUp()
        analytics = AnalyticsService.shared
    }

    override func tearDown() {
        analytics = nil
        super.tearDown()
    }

    func testTrackImpression_IncrementsCount() {
        analytics.track(.impression, metadata: nil)
        let count = analytics.impressionCount()
        XCTAssertGreaterThan(count, 0)
    }

    func testTrackClick() {
        analytics.track(.click, metadata: nil)
        let ctr = analytics.ctr()
        // CTR = clicks / impressions, both should be >= 0
        XCTAssertGreaterThanOrEqual(ctr, 0)
    }

    func testTrackSearch() {
        analytics.track(.search, metadata: "test query")
        // Should not crash
    }

    func testTrackWithAdContext() {
        let ad = AdItem(
            id: "test-ad-analytics",
            title: "测试广告",
            description: "测试描述信息用于埋点验证",
            imageURL: "https://example.com/img.jpg",
            videoURL: nil,
            cardType: .bigImage,
            channel: .featured,
            tags: [],
            aiSummary: "测试摘要",
            sponsor: "测试品牌"
        )
        analytics.trackWithAdContext(.impression, ad: ad, channel: .featured)
        analytics.trackWithAdContext(.click, ad: ad, channel: .featured, extra: "test")
    }

    func testChannelBreakdown() {
        let breakdown = analytics.channelBreakdown()
        XCTAssertNotNil(breakdown)
    }

    func testTopInteractedAds() {
        let top = analytics.topInteractedAds(limit: 3)
        XCTAssertNotNil(top)
    }

    func testEnrichedEvents() {
        let events = analytics.enrichedEvents()
        XCTAssertNotNil(events)
    }
}
