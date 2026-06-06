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

    // 趣味解读
    @Published var enhancedContents: [String: String] = [:]
    @Published var enhancingAdIds: Set<String> = []

    private let dataService = AdDataService()
    private let analytics = AnalyticsService.shared
    private let db = DatabaseManager.shared
    private var currentPage = 0
    private var shuffleSeed: UInt64 = UInt64.random(in: .min ... .max)
    private var preFilterShuffleSeed: UInt64?
    private var suppressLoadMoreUntil: Date = .distantPast
    private var userAdObserver: NSObjectProtocol?

    /// 用户偏好标签（从 UserDefaults 读取）
    private var favoriteTags: [String] {
        guard let data = UserDefaults.standard.data(forKey: "favorite_tags"),
              let tags = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return tags
    }

    /// 根据用户偏好标签 + 种子值对广告排序：匹配标签越多越靠前，同分时种子打散确保每次刷新顺序不同
    private func applyRecommendation(_ incomingAds: [AdItem]) -> [AdItem] {
        let favTags = favoriteTags
        let seed = shuffleSeed
        guard !favTags.isEmpty else {
            // 无偏好标签：种子值排序确保每次刷新顺序不同
            return incomingAds.sorted {
                ($0.id.hashValue ^ Int(truncatingIfNeeded: seed))
                    < ($1.id.hashValue ^ Int(truncatingIfNeeded: seed))
            }
        }
        return incomingAds.sorted { a, b in
            let scoreA = a.tags.filter { favTags.contains($0.name) }.count
            let scoreB = b.tags.filter { favTags.contains($0.name) }.count
            if scoreA != scoreB { return scoreA > scoreB }
            // 同分时种子打散
            return (a.id.hashValue ^ Int(truncatingIfNeeded: seed))
                < (b.id.hashValue ^ Int(truncatingIfNeeded: seed))
        }
    }

    var allAdsForCurrentChannel: [AdItem] {
        dataService.allAds(for: currentChannel)
    }

    func loadInitialData() async {
        interactionStates = db.loadAllInteractionStates()
        // 避免 .task 在详情返回后重复触发导致重新打乱
        if ads.isEmpty {
            await switchChannel(to: currentChannel)
        }

        userAdObserver = NotificationCenter.default.addObserver(
            forName: .userAdDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
    }

    deinit {
        if let observer = userAdObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func switchChannel(to channel: Channel) async {
        currentChannel = channel
        currentPage = 0
        hasMore = true
        isLoading = true
        activeTagFilter = nil
        shuffleSeed = UInt64.random(in: .min ... .max)
        ads = []
        await loadPage(1)
        isLoading = false
    }

    func refresh() async {
        isRefreshing = true
        currentPage = 0
        hasMore = true
        activeTagFilter = nil
        shuffleSeed = UInt64.random(in: .min ... .max)
        await loadPage(1)
        // 短暂延迟确保刷新动画可见
        try? await Task.sleep(nanoseconds: 400_000_000)
        isRefreshing = false
    }

    /// 从详情页返回时短暂禁止加载更多，避免 onAppear 误触发 reshuffle
    func suppressLoadMoreBriefly() {
        suppressLoadMoreUntil = Date().addingTimeInterval(1.0)
    }

    func loadMoreIfNeeded(currentItem: AdItem) async {
        guard hasMore, !isLoading,
              Date() > suppressLoadMoreUntil,
              let lastItem = ads.last, lastItem.id == currentItem.id else { return }
        isLoading = true
        await loadPage(currentPage + 1)
        isLoading = false
    }

    func applyTagFilter(_ tagName: String?) {
        let wasFiltered = activeTagFilter != nil

        // 点击已激活的标签时取消筛选
        if tagName != nil && activeTagFilter == tagName {
            activeTagFilter = nil
        } else {
            activeTagFilter = tagName
        }

        let isClearingFilter = wasFiltered && activeTagFilter == nil
        let isApplyingFirstFilter = !wasFiltered && activeTagFilter != nil

        currentPage = 0
        hasMore = true

        if isClearingFilter {
            // 取消筛选：恢复之前的种子，列表顺序与筛选前一致
            if let savedSeed = preFilterShuffleSeed {
                shuffleSeed = savedSeed
            }
            preFilterShuffleSeed = nil
        } else if isApplyingFirstFilter {
            // 首次应用筛选：保存当前种子，以便取消时恢复
            preFilterShuffleSeed = shuffleSeed
        }
        // 切换筛选时不做种子更新

        isFiltering = true
        Task {
            await loadPage(1)
            isFiltering = false
        }
    }

    private func loadPage(_ page: Int) async {
        do {
            if let filter = activeTagFilter {
                // 标签筛选：加载全部广告，客户端筛选以保留打乱顺序
                let allAds = dataService.allAds(for: currentChannel)
                let shuffled = applyRecommendation(allAds)
                ads = shuffled.filter { ad in
                    ad.tags.contains { $0.name == filter }
                }
                hasMore = false
                currentPage = page
            } else {
                let pageResult = try await dataService.fetchAds(
                    channel: currentChannel, page: page, pageSize: Constants.pageSize,
                    tagFilter: nil
                )
                if page == 1 {
                    ads = pageResult.ads
                } else {
                    ads.append(contentsOf: pageResult.ads)
                }
                ads = applyRecommendation(ads)
                currentPage = page
                hasMore = pageResult.hasMore
            }
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

    // MARK: - AI Enhance

    /// 触发 AI 趣味解读，结果缓存到 enhancedContents
    func enhanceAd(_ ad: AdItem, style: String = "funny") {
        let adId = ad.id
        guard !enhancingAdIds.contains(adId) else { return }

        enhancingAdIds.insert(adId)
        let styleLabel = enhanceStyleLabel(style)

        Task {
            do {
                let prompt = """
                你是一个创意广告改写助手。请对以下广告进行「\(styleLabel)」风格的趣味改写，\
                要求简洁有趣、让人愿意读完。只输出改写后的内容，不要输出任何解释说明。

                广告标题：\(ad.title)
                品牌：\(ad.sponsor)
                描述：\(ad.description)
                """
                let history = [ChatMessage(role: .user, content: prompt)]
                var result = ""
                for try await event in AIService.shared.chat(history: history) {
                    if case .contentDelta(let delta) = event {
                        result += delta
                    }
                }
                let trimmed = result.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    await MainActor.run {
                        enhancedContents[adId] = trimmed
                        enhancingAdIds.remove(adId)
                    }
                } else {
                    await MainActor.run { enhancingAdIds.remove(adId) }
                }
            } catch {
                await MainActor.run { enhancingAdIds.remove(adId) }
            }
        }
    }

    private func enhanceStyleLabel(_ style: String) -> String {
        switch style {
        case "funny": return "幽默段子"
        case "poetic": return "打油诗"
        case "story": return "微型故事"
        case "slogan": return "创意标语"
        default: return "幽默段子"
        }
    }
}
