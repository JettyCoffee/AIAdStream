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
            VStack(spacing: 0) {
                mediaSection

                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    Divider()
                    brandSection
                    if let summary = viewModel.summary {
                        aiSummarySection(summary)
                    }
                    if !viewModel.tags.isEmpty {
                        tagsSection
                    }
                    interactionSection
                    ctaButton
                }
                .padding(Constants.horizontalPadding)
                .padding(.top, 20)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                aidCapsule(ad.id)
                cardTypeBadge(ad.cardType)
                Spacer()
                Text(channelLabel(ad.channel))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ad.channel.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ad.channel.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(ad.title)
                .font(.system(size: 22, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Text(ad.sponsor)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Constants.Colors.secondaryText)
                Text("· 广告")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))
            }
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

    // MARK: - AI Summary

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
                .foregroundColor(.primary.opacity(0.75))
                .lineSpacing(4)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text("智能标签")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }

            let grouped = Dictionary(grouping: viewModel.tags) { $0.category }
            ForEach(TagCategory.allCases, id: \.self) { category in
                if let tags = grouped[category], !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue.opacity(0.7))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                            ForEach(tags) { tag in
                                Text(tag.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.75))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.blue.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Interaction

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
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            feedViewModel.trackClick(adId: ad.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 15))
                Text(ad.ctaText)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(feedViewModel.currentChannel.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 32)
    }

    // MARK: - Helpers

    private func aidCapsule(_ aid: String) -> some View {
        Text(truncatedAID(aid))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.gray.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func truncatedAID(_ aid: String) -> String {
        if aid.count <= 16 { return aid }
        return "\(String(aid.prefix(8)))…\(String(aid.suffix(6)))"
    }

    private func cardTypeBadge(_ type: AdCardType) -> some View {
        let label: String = {
            switch type {
            case .bigImage: return "大图"
            case .smallImage: return "小图"
            case .video: return "视频"
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Constants.Colors.tagBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

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
