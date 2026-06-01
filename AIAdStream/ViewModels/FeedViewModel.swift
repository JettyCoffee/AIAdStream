import SwiftUI
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var ads: [AdItem] = []
    @Published var currentChannel: Channel = .featured
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var hasMore = true
    @Published var interactionStates: [String: InteractionState] = [:]
    @Published var selectedAd: AdItem?
    @Published var activeTagFilter: String?

    @Published var isFiltering = false

    private let dataService = AdDataService()
    private let analytics = AnalyticsService.shared
    private let db = DatabaseManager.shared
    private var currentPage = 0

    /// 用户偏好标签（从 UserDefaults 读取）
    private var favoriteTags: [String] {
        guard let data = UserDefaults.standard.data(forKey: "favorite_tags"),
              let tags = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return tags
    }

    /// 根据用户偏好标签对广告重新排序：匹配标签越多越靠前
    private func applyRecommendation(_ incomingAds: [AdItem]) -> [AdItem] {
        let favTags = favoriteTags
        guard !favTags.isEmpty else { return incomingAds }
        return incomingAds.sorted { a, b in
            let scoreA = a.tags.filter { favTags.contains($0.name) }.count
            let scoreB = b.tags.filter { favTags.contains($0.name) }.count
            return scoreA > scoreB
        }
    }

    var allAdsForCurrentChannel: [AdItem] {
        dataService.allAds(for: currentChannel)
    }

    func loadInitialData() async {
        interactionStates = db.loadAllInteractionStates()
        await switchChannel(to: currentChannel)
    }

    func switchChannel(to channel: Channel) async {
        currentChannel = channel
        currentPage = 0
        hasMore = true
        isLoading = true
        activeTagFilter = nil
        ads = []
        await loadPage(1)
        isLoading = false
    }

    func refresh() async {
        isRefreshing = true
        currentPage = 0
        hasMore = true
        await loadPage(1)
        isRefreshing = false
    }

    func loadMoreIfNeeded(currentItem: AdItem) async {
        guard hasMore, !isLoading, let lastItem = ads.last, lastItem.id == currentItem.id else { return }
        isLoading = true
        await loadPage(currentPage + 1)
        isLoading = false
    }

    func applyTagFilter(_ tagName: String?) {
        // 点击已激活的标签时取消筛选
        if tagName != nil && activeTagFilter == tagName {
            activeTagFilter = nil
        } else {
            activeTagFilter = tagName
        }
        currentPage = 0
        hasMore = true
        isFiltering = true
        Task {
            await loadPage(1)
            isFiltering = false
        }
    }

    private func loadPage(_ page: Int) async {
        do {
            let pageResult = try await dataService.fetchAds(
                channel: currentChannel, page: page, pageSize: Constants.pageSize,
                tagFilter: activeTagFilter
            )
            if page == 1 {
                // 首页且无标签筛选时应用用户偏好排序
                ads = activeTagFilter == nil
                    ? applyRecommendation(pageResult.ads)
                    : pageResult.ads
            } else {
                ads.append(contentsOf: pageResult.ads)
            }
            currentPage = page
            hasMore = pageResult.hasMore
        } catch {
            hasMore = false
        }
    }

    func interactionState(for adId: String) -> InteractionState {
        interactionStates[adId] ?? InteractionState()
    }

    func toggleLike(for adId: String) {
        guard let ad = findAd(by: adId) else { return }
        var state = interactionState(for: adId)
        let wasLiked = state.isLiked
        state.isLiked.toggle()
        state.likeCount += state.isLiked ? 1 : -1
        update(state, for: adId)
        analytics.trackWithAdContext(.like, ad: ad, channel: currentChannel)
        analytics.trackStateChange(ad: ad, field: "isLiked", from: "\(wasLiked)", to: "\(state.isLiked)")
    }

    func toggleCollect(for adId: String) {
        guard let ad = findAd(by: adId) else { return }
        var state = interactionState(for: adId)
        let wasCollected = state.isCollected
        state.isCollected.toggle()
        update(state, for: adId)
        analytics.trackWithAdContext(.collect, ad: ad, channel: currentChannel)
        analytics.trackStateChange(ad: ad, field: "isCollected", from: "\(wasCollected)", to: "\(state.isCollected)")
    }

    func incrementShare(for adId: String) {
        guard let ad = findAd(by: adId) else { return }
        var state = interactionState(for: adId)
        let oldCount = state.shareCount
        state.shareCount += 1
        update(state, for: adId)
        analytics.trackWithAdContext(.share, ad: ad, channel: currentChannel)
        analytics.trackStateChange(ad: ad, field: "shareCount", from: "\(oldCount)", to: "\(state.shareCount)")
    }

    func trackImpression(adId: String) {
        guard let ad = findAd(by: adId) else { return }
        analytics.trackWithAdContext(.impression, ad: ad, channel: currentChannel)
    }

    func trackClick(adId: String) {
        guard let ad = findAd(by: adId) else { return }
        analytics.trackWithAdContext(.click, ad: ad, channel: currentChannel)
    }

    func trackTagClick(adId: String, tagName: String) {
        guard let ad = findAd(by: adId) else { return }
        analytics.trackWithAdContext(.tagClick, ad: ad, channel: currentChannel, extra: tagName)
    }

    private func update(_ state: InteractionState, for adId: String) {
        interactionStates[adId] = state
        db.saveInteractionState(state, for: adId)
    }

    private func findAd(by id: String) -> AdItem? {
        if let ad = ads.first(where: { $0.id == id }) { return ad }
        return dataService.fetchAd(by: id)
    }

    func ad(by id: String) -> AdItem? {
        if let ad = ads.first(where: { $0.id == id }) { return ad }
        return dataService.fetchAd(by: id)
    }

    var allTagsForFilter: [String] {
        dataService.allTags(for: currentChannel)
    }

    var tagsGroupedByCategory: [(category: TagCategory, tags: [String])] {
        let allTags = dataService.allTagsWithCategory(for: currentChannel)
        let grouped = Dictionary(grouping: allTags) { $0.category }
        return TagCategory.allCases.compactMap { category in
            let tags = grouped[category]?.map(\.name) ?? []
            return tags.isEmpty ? nil : (category, tags)
        }
    }

    var allAdsAcrossChannels: [AdItem] {
        dataService.allAdsAcrossChannels()
    }
}
