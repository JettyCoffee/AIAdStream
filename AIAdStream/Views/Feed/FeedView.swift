import SwiftUI

struct FeedView: View {
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var activeVideoId: String?
    @State private var savedScrollAdId: String?
    @State private var selectedAd: AdItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChannelTabBar(selectedChannel: $viewModel.currentChannel)
                    .onChange(of: viewModel.currentChannel) { _, newChannel in
                        savedScrollAdId = nil
                        Task { await viewModel.switchChannel(to: newChannel) }
                    }

                Divider().foregroundColor(Constants.Colors.separator)

                if viewModel.ads.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    feedScrollView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue.opacity(0.8))
                }
                ToolbarItem(placement: .principal) {
                    Text("AIAdStream")
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .task { await viewModel.loadInitialData() }
        }
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Button {
                viewModel.applyTagFilter(nil)
            } label: {
                HStack {
                    Text("全部")
                    if viewModel.activeTagFilter == nil { Image(systemName: "checkmark") }
                }
            }
            ForEach(viewModel.tagsGroupedByCategory, id: \.category) { group in
                Section(group.category.displayName) {
                    ForEach(group.tags, id: \.self) { tag in
                        Button {
                            viewModel.applyTagFilter(tag)
                        } label: {
                            HStack {
                                Text(tag)
                                if viewModel.activeTagFilter == tag { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: viewModel.activeTagFilter != nil
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease")
                .font(.system(size: 17))
                .foregroundColor(viewModel.activeTagFilter != nil
                    ? viewModel.currentChannel.accentColor : .primary)
        }
    }

    // MARK: - Feed

    private var feedScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Constants.cardSpacing) {
                    ForEach(viewModel.ads) { ad in
                        Button {
                            savedScrollAdId = ad.id
                            selectedAd = ad
                        } label: {
                            AdCardView(
                                ad: ad,
                                interactionState: bindingForAd(ad.id),
                                onLike: { viewModel.toggleLike(for: ad.id) },
                                onCollect: { viewModel.toggleCollect(for: ad.id) },
                                onShare: { viewModel.incrementShare(for: ad.id) },
                                onTagTap: { tag in
                                    viewModel.trackTagClick(adId: ad.id, tagName: tag.name)
                                    DispatchQueue.main.async {
                                        viewModel.applyTagFilter(tag.name)
                                    }
                                },
                                isActive: activeVideoId == ad.id,
                                activeTagFilter: viewModel.activeTagFilter,
                                enhancedContent: viewModel.enhancedContents[ad.id],
                                isEnhancing: viewModel.enhancingAdIds.contains(ad.id),
                                onEnhance: { viewModel.enhanceAd(ad) }
                            )
                        }
                        .buttonStyle(.plain)
                        .id(ad.id)
                        .onAppear {
                            viewModel.trackImpression(adId: ad.id)
                            if ad.cardType == .video { activeVideoId = ad.id }
                            Task { await viewModel.loadMoreIfNeeded(currentItem: ad) }
                        }
                        .onDisappear {
                            if ad.cardType == .video && activeVideoId == ad.id { activeVideoId = nil }
                        }
                    }
                    if viewModel.hasMore { LoadingFooterView() }
                }
                .padding(.vertical, 8)
            }
            .refreshable { await viewModel.refresh() }
            .navigationDestination(item: $selectedAd) { ad in
                AdDetailView(ad: ad).environmentObject(viewModel)
            }
            .onChange(of: selectedAd) { _, newValue in
                if newValue != nil {
                    // 进入详情页：禁止 onAppear 误触发 loadMore
                    viewModel.suppressLoadMoreBriefly()
                } else if let target = savedScrollAdId {
                    // 从详情页返回：禁止返回后的 onAppear，恢复滚动位置
                    viewModel.suppressLoadMoreBriefly()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        proxy.scrollTo(target)
                    }
                }
            }
        }
    }

    // MARK: - Misc

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(Constants.Colors.secondaryText)
            Text("暂无内容")
                .font(.system(size: 16))
                .foregroundColor(Constants.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bindingForAd(_ adId: String) -> Binding<InteractionState> {
        Binding(
            get: { viewModel.interactionState(for: adId) },
            set: { viewModel.interactionStates[adId] = $0 }
        )
    }
}
