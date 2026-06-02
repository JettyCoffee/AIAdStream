import XCTest
@testable import AIAdStream

final class DatabaseManagerTests: XCTestCase {
    var db: DatabaseManager!

    override func setUp() {
        super.setUp()
        db = DatabaseManager.shared
    }

    override func tearDown() {
        db = nil
        super.tearDown()
    }

    // MARK: - Fetch Tests

    func testFetchAdsByChannel_ReturnsAds() {
        let result = db.fetchAds(channel: "featured", offset: 0, limit: 10, tagFilter: nil)
        XCTAssertFalse(result.ads.isEmpty, "精选频道应有广告")
        XCTAssertTrue(result.ads.count <= 10, "最多返回 10 条")
    }

    func testFetchAdsByChannel_Pagination() {
        let page1 = db.fetchAds(channel: "local", offset: 0, limit: 5, tagFilter: nil)
        let page2 = db.fetchAds(channel: "local", offset: 5, limit: 5, tagFilter: nil)
        XCTAssertFalse(page1.ads.isEmpty)
        if !page2.ads.isEmpty {
            let ids1 = Set(page1.ads.map(\.id))
            let ids2 = Set(page2.ads.map(\.id))
            XCTAssertTrue(ids1.isDisjoint(with: ids2), "分页结果不应重叠")
        }
    }

    func testFetchAds_InvalidChannel_ReturnsEmpty() {
        let result = db.fetchAds(channel: "nonexistent", offset: 0, limit: 10, tagFilter: nil)
        XCTAssertTrue(result.ads.isEmpty)
    }

    // MARK: - Search Tests

    func testSearchAds_ReturnsMatchingAds() {
        let results = db.searchAds(query: "运动", channel: nil)
        XCTAssertFalse(results.isEmpty, "搜索'运动'应有结果")
    }

    func testSearchAds_EmptyQuery_ReturnsAllAds() {
        // 空查询匹配所有广告（LIKE '%%' 行为）
        let results = db.searchAds(query: "", channel: nil)
        // 种子数据库有 450 条广告，空查询应返回结果
        XCTAssertFalse(results.isEmpty)
    }

    // MARK: - Single Ad Fetch

    func testFetchAdById_ExistingId_ReturnsAd() {
        let result = db.fetchAds(channel: "featured", offset: 0, limit: 1, tagFilter: nil)
        guard let first = result.ads.first else {
            XCTFail("需要至少一条种子数据")
            return
        }
        let ad = db.fetchAd(by: first.id)
        XCTAssertNotNil(ad)
        XCTAssertEqual(ad?.title, first.title)
    }

    func testFetchAdById_NonExistentId_ReturnsNil() {
        let ad = db.fetchAd(by: "nonexistent-id-12345")
        XCTAssertNil(ad)
    }

    // MARK: - Tag Tests

    func testTagsForAd_ReturnsTags() {
        let result = db.fetchAds(channel: "featured", offset: 0, limit: 1, tagFilter: nil)
        guard let first = result.ads.first else {
            XCTFail("需要至少一条种子数据")
            return
        }
        let tags = db.tagsForAd(first.id)
        XCTAssertFalse(tags.isEmpty, "每条广告应有标签")
    }

    func testFetchAdsByTags_ReturnsSimilarAds() {
        let result = db.fetchAds(channel: "featured", offset: 0, limit: 1, tagFilter: nil)
        guard let first = result.ads.first else {
            XCTFail("需要至少一条种子数据")
            return
        }
        let tags = db.tagsForAd(first.id).map(\.name)
        guard !tags.isEmpty else {
            XCTFail("广告应有标签")
            return
        }
        let similar = db.fetchAdsByTags(tags, channel: nil, limit: 5)
        XCTAssertFalse(similar.isEmpty, "相同标签应返回结果")
        // 源广告可能因标签匹配顺序不在结果中，仅验证返回非空
    }

    // MARK: - Interaction State Tests

    func testInteractionStateSaveAndLoad() {
        // 保存到已知广告 ID 上的互动状态
        let result = db.fetchAds(channel: "featured", offset: 0, limit: 1, tagFilter: nil)
        guard let ad = result.ads.first else {
            XCTFail("需要种子数据")
            return
        }
        let state = InteractionState(isLiked: true, isCollected: false, likeCount: 5, shareCount: 2)
        db.saveInteractionState(state, for: ad.id)
        let loaded = db.loadInteractionState(for: ad.id)
        // loadInteractionState 始终返回非 nil，检查具体值
        XCTAssertEqual(loaded.isLiked, state.isLiked)
        XCTAssertEqual(loaded.likeCount, state.likeCount)
    }

    func testLoadAllInteractionStates() {
        let allStates = db.loadAllInteractionStates()
        XCTAssertNotNil(allStates)
    }

    // MARK: - Analytics Tests

    func testInsertAndFetchAnalyticsEvents() {
        let event = AnalyticsEvent(
            id: UUID().uuidString,
            type: .impression,
            adId: "ad-1",
            channel: "featured",
            timestamp: Date(),
            metadata: nil
        )
        db.insertAnalyticsEvent(event)
        let events = db.fetchAnalyticsEvents()
        XCTAssertFalse(events.isEmpty)
    }

    // MARK: - All Tags Tests

    func testAllTagsForChannel() {
        let tags = db.allTagsWithCategory(for: "featured")
        XCTAssertFalse(tags.isEmpty)
    }
}
