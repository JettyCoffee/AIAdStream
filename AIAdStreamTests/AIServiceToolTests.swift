import XCTest
@testable import AIAdStream

final class AIServiceToolTests: XCTestCase {

    func testSearchAds_WithQuery_ReturnsResults() {
        let results = DatabaseManager.shared.searchAds(query: "咖啡", channel: nil)
        XCTAssertFalse(results.isEmpty, "数据库应包含咖啡相关广告")
    }

    func testSearchAds_WithChannel_ReturnsFiltered() {
        let results = DatabaseManager.shared.searchAds(query: "手机", channel: "ecommerce")
        for ad in results {
            XCTAssertEqual(ad.channel.rawValue, "ecommerce")
        }
    }

    func testGetAdDetail_ExistingId_ReturnsAd() {
        let result = DatabaseManager.shared.fetchAds(channel: "featured", offset: 0, limit: 1, tagFilter: nil)
        guard let first = result.ads.first else {
            XCTFail("需要种子数据")
            return
        }
        let detail = DatabaseManager.shared.fetchAd(by: first.id)
        XCTAssertNotNil(detail)
        XCTAssertEqual(detail?.id, first.id)
    }

    func testGetSimilarAds_ExistingId_ReturnsAds() {
        let result = DatabaseManager.shared.fetchAds(channel: "featured", offset: 0, limit: 1, tagFilter: nil)
        guard let first = result.ads.first else {
            XCTFail("需要种子数据")
            return
        }
        let tags = DatabaseManager.shared.tagsForAd(first.id).map(\.name)
        guard !tags.isEmpty else {
            XCTFail("广告应有标签")
            return
        }
        let similar = DatabaseManager.shared.fetchAdsByTags(tags, channel: nil, limit: 3)
        XCTAssertFalse(similar.isEmpty)
    }

    func testGetSimilarAds_InvalidId_ReturnsEmpty() {
        let similar = DatabaseManager.shared.fetchAdsByTags(["不存在的标签"], channel: nil, limit: 3)
        XCTAssertTrue(similar.isEmpty)
    }
}
