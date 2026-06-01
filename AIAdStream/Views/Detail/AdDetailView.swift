import SwiftUI
import AVKit

struct AdDetailView: View {
    let ad: AdItem
    @EnvironmentObject var feedViewModel: FeedViewModel
    @StateObject private var viewModel: DetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var isMuted = false
    @State private var player: AVPlayer?
    @FocusState private var isChatFocused: Bool
    @State private var showAISheet = false

    init(ad: AdItem) {
        self.ad = ad
        _viewModel = StateObject(wrappedValue: DetailViewModel(ad: ad))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 可滚动内容区
            ScrollView {
                VStack(spacing: 0) {
                    mediaSection

                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        brandSection
                    }
                    .padding(Constants.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 100) // 为底部固定栏留空间
                }
            }

            // 底部固定栏：互动按钮 + AI 输入
            bottomBar
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    feedViewModel.incrementShare(for: ad.id)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showAISheet) {
            aiChatSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            if ad.cardType == .video {
                setupPlayer()
                player?.play()
                isPlaying = true
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        Group {
            if ad.cardType == .video {
                ZStack {
                    Rectangle().fill(.black)
                    if let player = player {
                        VideoPlayerView(player: player)
                    }
                    if !isPlaying {
                        LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                    }

                    LinearGradient(
                        colors: [.black.opacity(0.3), .clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                isMuted.toggle()
                                player?.isMuted = isMuted
                            } label: {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding(12)
                        }
                        Spacer()
                    }
                }
                .aspectRatio(16/9, contentMode: .fit)
                .contentShape(Rectangle())
                .onTapGesture { togglePlay() }

            } else {
                LazyImageView(imageName: ad.imageURL, contentMode: .fit)
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipped()
                    .background(Color.black.opacity(0.03))
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 赞助商 + 频道
            HStack(spacing: 6) {
                Text(ad.sponsor)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Constants.Colors.secondaryText)
                Text("· 广告")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))

                Spacer()

                Text(channelLabel(ad.channel))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ad.channel.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ad.channel.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            // 标签（按分类展示）
            if !viewModel.tags.isEmpty {
                let grouped = Dictionary(grouping: viewModel.tags) { $0.category }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.tags) { tag in
                            Text(tag.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary.opacity(0.65))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Constants.Colors.tagBackground)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // 标题
            Text(ad.title)
                .font(.system(size: 22, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Brand

    private var brandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("品牌介绍")
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(ad.description)
                .font(.system(size: 15))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(5)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 10) {
                // 互动栏
                let interactionBinding = Binding(
                    get: { feedViewModel.interactionState(for: ad.id) },
                    set: { feedViewModel.interactionStates[ad.id] = $0 }
                )
                InteractionBar(
                    adId: ad.id,
                    state: interactionBinding,
                    onLike: { feedViewModel.toggleLike(for: ad.id) },
                    onCollect: { feedViewModel.toggleCollect(for: ad.id) },
                    onShare: { feedViewModel.incrementShare(for: ad.id) }
                )

                // AI 输入栏
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.purple.opacity(0.6))
                        Text("咨询 AI 助手了解更多...")
                            .font(.system(size: 14))
                            .foregroundColor(Constants.Colors.secondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onTapGesture { showAISheet = true }
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, 10)
            .background(.white)
        }
    }

    // MARK: - AI Chat Sheet

    private var aiChatSheet: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundColor(.purple)
                    Text("AI 助手")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                }
                Spacer()
                Button {
                    showAISheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, 12)

            Divider()

            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // 开场白
                        if viewModel.chatMessages.isEmpty && !viewModel.isChatStreaming {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                    .padding(.top, 4)
                                Text("我是你的广告智能助手，关于「\(ad.title)」有什么想了解的？")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary.opacity(0.7))
                                    .padding(10)
                                    .background(Color.purple.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // 对话消息
                        ForEach(viewModel.chatMessages) { msg in
                            detailChatBubble(msg)
                        }

                        // 流式输出
                        if viewModel.isChatStreaming && !viewModel.chatStreamingContent.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                    .padding(.top, 4)
                                Text(viewModel.chatStreamingContent)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .padding(10)
                                    .background(Color.purple.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // 推荐广告
                        if !viewModel.chatRecommendedAds.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(viewModel.chatRecommendedAds) { similarAd in
                                    NavigationLink {
                                        AdDetailView(ad: similarAd)
                                            .environmentObject(feedViewModel)
                                    } label: {
                                        HStack(spacing: 10) {
                                            LazyImageView(imageName: similarAd.imageURL, contentMode: .fill)
                                                .frame(width: 44, height: 44)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(similarAd.title)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .lineLimit(1)
                                                Text(similarAd.sponsor)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Constants.Colors.secondaryText)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10))
                                                .foregroundColor(Constants.Colors.secondaryText)
                                        }
                                        .padding(8)
                                        .background(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // 错误
                        if let error = viewModel.chatErrorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .padding(8)
                                .background(Color.orange.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Color.clear.frame(height: 1).id("chatBottom")
                    }
                    .padding(Constants.horizontalPadding)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.chatStreamingContent) { _, _ in
                    withAnimation { proxy.scrollTo("chatBottom", anchor: .bottom) }
                }
                .onChange(of: viewModel.chatMessages.count) { _, _ in
                    withAnimation { proxy.scrollTo("chatBottom", anchor: .bottom) }
                }
            }

            Divider()

            // 底部输入栏
            HStack(spacing: 8) {
                TextField("询问关于此广告...", text: $viewModel.chatInput, axis: .vertical)
                    .font(.system(size: 14))
                    .focused($isChatFocused)
                    .submitLabel(.send)
                    .onSubmit { viewModel.sendChatMessage() }
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    viewModel.sendChatMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(
                            viewModel.chatInput.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray.opacity(0.3)
                                : Color.purple
                        )
                }
                .disabled(viewModel.chatInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, 8)
            .background(.white)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.97))
    }

    private func detailChatBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if msg.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                    .padding(.top, 4)
            } else {
                Spacer()
            }

            Text(msg.content)
                .font(.system(size: 14))
                .foregroundColor(msg.role == .user ? .white : .primary.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    msg.role == .user
                        ? Color.purple.opacity(0.8)
                        : Color.purple.opacity(0.04)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if msg.role == .user {
                EmptyView()
            }
        }
    }

    // MARK: - Helpers

    private func channelLabel(_ channel: Channel) -> String {
        channel.displayName
    }

    // MARK: - Player

    private func setupPlayer() {
        guard player == nil, let url = URL(string: ad.videoURL ?? "") else { return }
        let p = VideoPlayerPool.shared.dequeuePlayer()
        p.replaceCurrentItem(with: AVPlayerItem(url: url))
        p.isMuted = false
        isMuted = false
        self.player = p
    }

    private func togglePlay() {
        if isPlaying {
            player?.pause()
        } else {
            if player == nil { setupPlayer() }
            player?.play()
        }
        isPlaying.toggle()
    }

    private func cleanupPlayer() {
        if let p = player {
            VideoPlayerPool.shared.recyclePlayer(p)
            player = nil
        }
    }
}
