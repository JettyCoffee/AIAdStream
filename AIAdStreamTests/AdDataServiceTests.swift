import XCTest
@testable import AIAdStream

final class AdDataServiceTests: XCTestCase {
    var service: AdDataService!

    override func setUp() {
        super.setUp()
        service = AdDataService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    func testFetchAds_FeaturedChannel_ReturnsResults() async throws {
        let page = try await service.fetchAds(channel: .featured, page: 1, pageSize: 5)
        XCTAssertFalse(page.ads.isEmpty)
        page.ads.forEach { XCTAssertEqual($0.channel, .featured) }
    }

    func testFetchAds_EcommerceChannel_ReturnsResults() async throws {
        let page = try await service.fetchAds(channel: .ecommerce, page: 1, pageSize: 5)
        XCTAssertFalse(page.ads.isEmpty)
        page.ads.forEach { XCTAssertEqual($0.channel, .ecommerce) }
    }

    func testFetchAds_LocalChannel_ReturnsResults() async throws {
        let page = try await service.fetchAds(channel: .local, page: 1, pageSize: 5)
        XCTAssertFalse(page.ads.isEmpty)
        page.ads.forEach { XCTAssertEqual($0.channel, .local) }
    }

    func testFetchAds_Pagination_Boundary() async throws {
        let page = try await service.fetchAds(channel: .featured, page: 1, pageSize: 3)
        XCTAssertTrue(page.ads.count <= 3)
    }

    func testAllTags_ReturnsTags() {
        let tags = service.allTags(for: .featured)
        XCTAssertFalse(tags.isEmpty)
    }

    func testAllTagsWithCategory_ReturnsStructuredTags() {
        let tags = service.allTagsWithCategory(for: .featured)
        XCTAssertFalse(tags.isEmpty)
        for tag in tags {
            XCTAssertFalse(tag.name.isEmpty)
        }
    }

    func testFetchAdById_Existing_ReturnsAd() async throws {
        let page = try await service.fetchAds(channel: .featured, page: 1, pageSize: 1)
        guard let first = page.ads.first else {
            XCTFail("需要种子数据")
            return
        }
        let fetched = service.fetchAd(by: first.id)
        XCTAssertNotNil(fetched)
    }

    func testAllAdsAcrossChannels_ReturnsAllChannels() {
        let ads = service.allAdsAcrossChannels()
        let channels = Set(ads.map(\.channel))
        XCTAssertTrue(channels.contains(.featured))
        XCTAssertTrue(channels.contains(.ecommerce))
    }
}
