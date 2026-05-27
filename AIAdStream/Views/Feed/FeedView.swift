import SwiftUI

struct FeedView: View {
    @EnvironmentObject var viewModel: FeedViewModel
    @State private var activeVideoId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChannelTabBar(selectedChannel: $viewModel.currentChannel)
                    .onChange(of: viewModel.currentChannel) { _, newChannel in
                        Task {
                            await viewModel.switchChannel(to: newChannel)
                        }
                    }

                Divider()
                    .foregroundColor(Constants.Colors.separator)

                if viewModel.ads.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    feedScrollView
                }
            }
            .background(Color(red: 0.97, green: 0.97, blue: 0.97))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AIAdStream")
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .task {
                await viewModel.loadInitialData()
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                viewModel.activeTagFilter = nil
                viewModel.applyTagFilter(nil)
            } label: {
                HStack {
                    Text("全部")
                    if viewModel.activeTagFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(viewModel.tagsGroupedByCategory, id: \.category) { group in
                Section(group.category.displayName) {
                    ForEach(group.tags, id: \.self) { tag in
                        Button {
                            viewModel.activeTagFilter = tag
                            viewModel.applyTagFilter(tag)
                        } label: {
                            HStack {
                                Text(tag)
                                if viewModel.activeTagFilter == tag {
                                    Image(systemName: "checkmark")
                                }
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
                    ? viewModel.currentChannel.accentColor
                    : .primary)
        }
    }

    private var feedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: Constants.cardSpacing) {
                ForEach(viewModel.ads) { ad in
                    NavigationLink {
                        AdDetailView(ad: ad)
                            .environmentObject(viewModel)
                    } label: {
                        AdCardView(
                            ad: ad,
                            interactionState: bindingForAd(ad.id),
                            onLike: { viewModel.toggleLike(for: ad.id) },
                            onCollect: { viewModel.toggleCollect(for: ad.id) },
                            onShare: { viewModel.incrementShare(for: ad.id) },
                            onTagTap: { tag in
                                viewModel.trackTagClick(adId: ad.id, tagName: tag.name)
                                viewModel.activeTagFilter = tag.name
                                viewModel.applyTagFilter(tag.name)
                            },
                            isActive: activeVideoId == ad.id
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        viewModel.trackImpression(adId: ad.id)
                        if ad.cardType == .video {
                            activeVideoId = ad.id
                        }
                        Task {
                            await viewModel.loadMoreIfNeeded(currentItem: ad)
                        }
                    }
                    .onDisappear {
                        if ad.cardType == .video && activeVideoId == ad.id {
                            activeVideoId = nil
                        }
                    }
                }

                if viewModel.hasMore {
                    LoadingFooterView()
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

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
