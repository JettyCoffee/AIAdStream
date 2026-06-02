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
    @State private var panelState: AIPanelState = .bar

    init(ad: AdItem) {
        self.ad = ad
        _viewModel = StateObject(wrappedValue: DetailViewModel(ad: ad))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
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
                        .padding(.bottom, max(100, panelState.height(in: geometry) + 16))
                    }
                }

                // 半透明遮罩（面板展开时）
                if panelState != .bar {
                    Color.black.opacity(dimmingOpacity)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                panelState = .bar
                            }
                        }
                }

                // 可拖动 AI 面板
                DraggableAIPanel(
                    ad: ad,
                    viewModel: viewModel,
                    feedViewModel: feedViewModel,
                    panelState: $panelState
                )
                .padding(.horizontal, panelState == .bar ? 0 : 0)
            }
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

    // MARK: - Dimming

    private var dimmingOpacity: Double {
        switch panelState {
        case .bar:    return 0
        case .medium: return 0.15
        case .large:  return 0.35
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
                LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipped()
                    .background(Color.black)
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

            // 标签
            if !viewModel.tags.isEmpty {
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
