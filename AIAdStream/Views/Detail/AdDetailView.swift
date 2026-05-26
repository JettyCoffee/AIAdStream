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

    init(ad: AdItem) {
        self.ad = ad
        _viewModel = StateObject(wrappedValue: DetailViewModel(ad: ad))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mediaSection
                    .frame(height: 320)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ad.title)
                                .font(.system(size: 22, weight: .bold))
                            Text(ad.sponsor)
                                .font(.system(size: 14))
                                .foregroundColor(Constants.Colors.secondaryText)
                        }
                        Spacer()
                        Text("广告")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Constants.Colors.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Constants.Colors.tagBackground)
                            .clipShape(Capsule())
                    }

                    Divider()

                    Text("品牌介绍")
                        .font(.system(size: 16, weight: .semibold))
                    Text(ad.description)
                        .font(.system(size: 15))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineSpacing(4)

                    if let summary = viewModel.summary {
                        aiSummarySection(summary)
                    }

                    if !viewModel.tags.isEmpty {
                        tagsSection
                    }

                    Divider()

                    interactionSection

                    ctaButton
                }
                .padding(Constants.horizontalPadding)
                .padding(.top, 16)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    feedViewModel.incrementShare(for: ad.id)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .task {
            await viewModel.loadAIData()
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

                    VStack {
                        Spacer()
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
                    }
                }
                .onTapGesture {
                    togglePlay()
                }
            } else {
                LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                    .clipped()
            }
        }
    }

    private func aiSummarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundColor(.purple)
                Text("AI 摘要")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.purple)
            }

            Text(summary)
                .font(.system(size: 14))
                .foregroundColor(.primary.opacity(0.8))
                .lineSpacing(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text("智能标签")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(viewModel.tags) { tag in
                    HStack(spacing: 4) {
                        Text(tag.category.displayName)
                            .font(.system(size: 9))
                            .foregroundColor(.blue.opacity(0.6))
                        Text(tag.name)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var interactionSection: some View {
        let interactionBinding = Binding(
            get: { feedViewModel.interactionState(for: ad.id) },
            set: { feedViewModel.interactionStates[ad.id] = $0 }
        )

        return InteractionBar(
            adId: ad.id,
            state: interactionBinding,
            onLike: { feedViewModel.toggleLike(for: ad.id) },
            onCollect: { feedViewModel.toggleCollect(for: ad.id) },
            onShare: { feedViewModel.incrementShare(for: ad.id) }
        )
    }

    private var ctaButton: some View {
        Button {
            feedViewModel.trackClick(adId: ad.id)
        } label: {
            Text(ad.ctaText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(feedViewModel.currentChannel.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 24)
    }

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
