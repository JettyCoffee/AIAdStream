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

    private let dataService = AdDataService()
    private let aiService = AIService()
    private let analytics = AnalyticsService.shared
    private let db = DatabaseManager.shared
    private var currentPage = 0
    private var aiTask: Task<Void, Never>?

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
        await generateTagsForVisibleAds()
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
        activeTagFilter = tagName
        currentPage = 0
        hasMore = true
        ads = []
        Task {
            await loadPage(1)
        }
    }

    private func loadPage(_ page: Int) async {
        do {
            let pageResult = try await dataService.fetchAds(
                channel: currentChannel, page: page, pageSize: Constants.pageSize,
                tagFilter: activeTagFilter
            )
            if page == 1 {
                ads = pageResult.ads
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
        var state = interactionState(for: adId)
        state.isLiked.toggle()
        state.likeCount += state.isLiked ? 1 : -1
        update(state, for: adId)
        analytics.track(.like, adId: adId, channel: currentChannel)
    }

    func toggleCollect(for adId: String) {
        var state = interactionState(for: adId)
        state.isCollected.toggle()
        update(state, for: adId)
        analytics.track(.collect, adId: adId, channel: currentChannel)
    }

    func incrementShare(for adId: String) {
        var state = interactionState(for: adId)
        state.shareCount += 1
        update(state, for: adId)
        analytics.track(.share, adId: adId, channel: currentChannel)
    }

    func trackImpression(adId: String) {
        analytics.track(.impression, adId: adId, channel: currentChannel)
    }

    func trackClick(adId: String) {
        analytics.track(.click, adId: adId, channel: currentChannel)
    }

    func trackTagClick(adId: String, tagName: String) {
        analytics.track(.tagClick, adId: adId, channel: currentChannel, metadata: tagName)
    }

    private func update(_ state: InteractionState, for adId: String) {
        interactionStates[adId] = state
        db.saveInteractionState(state, for: adId)
    }

    private func generateTagsForVisibleAds() async {
        aiTask?.cancel()
        aiTask = Task {
            for ad in ads.prefix(5) {
                guard !Task.isCancelled else { return }
                if db.tagsForAd(ad.id).isEmpty {
                    let tags = await aiService.generateTags(for: ad)
                    if let index = ads.firstIndex(where: { $0.id == ad.id }) {
                        ads[index].tags = tags
                    }
                }
            }
        }
    }

    func ad(by id: String) -> AdItem? {
        if let ad = ads.first(where: { $0.id == id }) { return ad }
        return dataService.fetchAd(by: id)
    }

    var allTagsForFilter: [String] {
        dataService.allTags(for: currentChannel)
    }

    var allAdsAcrossChannels: [AdItem] {
        dataService.allAdsAcrossChannels()
    }
}
