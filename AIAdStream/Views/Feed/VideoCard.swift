import SwiftUI
import AVKit

struct VideoCard: View {
    let ad: AdItem
    let interactionState: Binding<InteractionState>
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    let isActive: Bool
    var activeTagFilter: String?

    var enhancedContent: String? = nil
    var isEnhancing: Bool = false
    var onEnhance: (() -> Void)? = nil

    @State private var isPlaying = false
    @State private var isMuted = true
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 视频区
            ZStack {
                Rectangle().fill(.black)
                if let player = player {
                    VideoPlayerView(player: player)
                }
                if !isPlaying {
                    LazyImageView(imageName: ad.imageURL, contentMode: .fill).clipped()
                }

                CardVideoOverlay(
                    isPlaying: isPlaying,
                    isMuted: isMuted,
                    onTogglePlay: { togglePlay() },
                    onToggleMute: {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    }
                )
            }
            .frame(height: 260)
            .highPriorityGesture(
                TapGesture().onEnded {
                    if !isPlaying {
                        setupPlayer()
                        player?.play()
                        isPlaying = true
                    }
                }
            )

            // 信息区
            VStack(alignment: .leading, spacing: 10) {
                CardSponsorLabel(sponsor: ad.sponsor)
                    .font(.system(size: 12, weight: .medium))

                CardTitleLabel(title: ad.title)

                if !ad.tags.isEmpty {
                    CardTagRow(
                        tags: ad.tags,
                        highlightedTagName: activeTagFilter,
                        highlightColor: ad.channel.accentColor,
                        onTagTap: onTagTap
                    )
                }

                CardAISummary(text: ad.aiSummary)

                if let content = enhancedContent {
                    EnhanceBanner(text: content) { onEnhance?() }
                }

                HStack {
                    EnhanceButton(
                        isLoading: isEnhancing,
                        hasContent: enhancedContent != nil,
                        action: { onEnhance?() }
                    )
                    Spacer()
                    InteractionBar(
                        adId: ad.id,
                        state: interactionState,
                        onLike: onLike,
                        onCollect: onCollect,
                        onShare: onShare
                    )
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
        }
        .cardStyle()
        .onChange(of: isActive) { _, active in
            if active {
                setupPlayer()
                player?.play()
                isPlaying = true
            } else {
                player?.pause()
                isPlaying = false
                cleanupPlayer()
            }
        }
        .onDisappear {
            player?.pause()
            cleanupPlayer()
        }
    }

    private func setupPlayer() {
        guard player == nil, let url = URL(string: ad.videoURL ?? "") else { return }
        let p = VideoPlayerPool.shared.dequeuePlayer()
        p.replaceCurrentItem(with: AVPlayerItem(url: url))
        p.isMuted = isMuted
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

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
