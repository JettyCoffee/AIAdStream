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

    @State private var isPlaying = false
    @State private var isMuted = true
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Rectangle().fill(.black)
                if let player = player {
                    VideoPlayerView(player: player)
                }
                if !isPlaying {
                    LazyImageView(imageName: ad.imageURL, contentMode: .fill).clipped()
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                if !isPlaying {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }

                VStack {
                    Spacer()
                    HStack {
                        Button {
                            togglePlay()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())

                        Spacer()

                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
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

            VStack(alignment: .leading, spacing: 10) {
                Text(ad.sponsor)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Constants.Colors.secondaryText)

                Text(ad.title)
                    .font(.system(size: 16, weight: .semibold))

                if let summary = ad.aiSummary {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(.purple.opacity(0.6))
                            .padding(.top, 1)
                        Text(summary)
                            .font(.system(size: 13))
                            .foregroundColor(.primary.opacity(0.7))
                            .lineSpacing(3)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !ad.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ad.tags) { tag in
                                TagChipView(
                                    tag: tag,
                                    isHighlighted: tag.name == activeTagFilter,
                                    highlightColor: ad.channel.accentColor
                                ) { onTagTap(tag) }
                            }
                        }
                    }
                }

                InteractionBar(
                    adId: ad.id,
                    state: interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .background(.white)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal, 16)
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
