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

                tagFilterBar

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
                    HStack(spacing: 6) {
                        Text(viewModel.currentChannel.displayName)
                            .font(.system(size: 17, weight: .semibold))
                        if let filter = viewModel.activeTagFilter {
                            Image(systemName: "line.horizontal.3.decrease.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(viewModel.currentChannel.accentColor)
                            Text(filter)
                                .font(.system(size: 12))
                                .foregroundColor(viewModel.currentChannel.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(viewModel.currentChannel.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .task {
                await viewModel.loadInitialData()
            }
        }
    }

    private var tagFilterBar: some View {
        let tags = viewModel.allTagsForFilter
        guard !tags.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.activeTagFilter = nil
                            viewModel.applyTagFilter(nil)
                        }
                    } label: {
                        Text("全部")
                            .font(.system(size: 12, weight: viewModel.activeTagFilter == nil ? .semibold : .regular))
                            .foregroundColor(viewModel.activeTagFilter == nil ? .white : .primary.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                viewModel.activeTagFilter == nil
                                    ? viewModel.currentChannel.accentColor
                                    : Constants.Colors.tagBackground
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(tags, id: \.self) { tag in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                let isActive = viewModel.activeTagFilter == tag
                                viewModel.activeTagFilter = isActive ? nil : tag
                                viewModel.applyTagFilter(isActive ? nil : tag)
                            }
                        } label: {
                            Text(tag)
                                .font(.system(size: 12, weight: viewModel.activeTagFilter == tag ? .semibold : .regular))
                                .foregroundColor(viewModel.activeTagFilter == tag ? .white : .primary.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    viewModel.activeTagFilter == tag
                                        ? viewModel.currentChannel.accentColor
                                        : Constants.Colors.tagBackground
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, 8)
            }
        )
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
