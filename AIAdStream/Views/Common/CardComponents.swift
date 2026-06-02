import SwiftUI

// MARK: - Standardized Card Sub-Components

/// 广告卡片底部信息区（标题、摘要、标签、互动栏）
struct CardInfoSection: View {
    let ad: AdItem
    @Binding var interactionState: InteractionState
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    var activeTagFilter: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !ad.tags.isEmpty {
                CardTagRow(
                    tags: ad.tags,
                    highlightedTagName: activeTagFilter,
                    highlightColor: ad.channel.accentColor,
                    onTagTap: onTagTap
                )
            }

            CardAISummary(text: ad.aiSummary)

            HStack {
                CardSponsorLabel(sponsor: ad.sponsor)
                Spacer()
                InteractionBar(
                    adId: ad.id,
                    state: $interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare
                )
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }
}

/// 广告卡片底部信息区（紧凑版，用于 SmallImageCard 右侧）
struct CardInfoSectionCompact: View {
    let ad: AdItem
    @Binding var interactionState: InteractionState
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    var activeTagFilter: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardSponsorLabel(sponsor: ad.sponsor)

            CardTitleLabel(title: ad.title, lineLimit: 2)
                .font(.system(size: 14, weight: .semibold))

            if !ad.tags.isEmpty {
                CardTagRow(
                    tags: Array(ad.tags.prefix(3)),
                    highlightedTagName: activeTagFilter,
                    highlightColor: ad.channel.accentColor,
                    onTagTap: onTagTap
                )
            }

            CardAISummary(text: ad.aiSummary)

            InteractionBar(
                adId: ad.id,
                state: $interactionState,
                onLike: onLike,
                onCollect: onCollect,
                onShare: onShare
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Sponsor Label

struct CardSponsorLabel: View {
    let sponsor: String

    var body: some View {
        Text(sponsor)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Constants.Colors.secondaryText)
    }
}

// MARK: - Title Label

struct CardTitleLabel: View {
    let title: String
    var lineLimit: Int = 2
    var font: Font = .system(size: 16, weight: .semibold)

    var body: some View {
        Text(title)
            .font(font)
            .lineLimit(lineLimit)
    }
}

// MARK: - AI Summary

struct CardAISummary: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundColor(.purple.opacity(0.5))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.65))
                .lineSpacing(3)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tag Row

struct CardTagRow: View {
    let tags: [AITag]
    var highlightedTagName: String?
    var highlightColor: Color = .blue
    var onTagTap: ((AITag) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags) { tag in
                    TagChipView(
                        tag: tag,
                        isHighlighted: tag.name == highlightedTagName,
                        highlightColor: highlightColor
                    ) {
                        onTagTap?(tag)
                    }
                }
            }
        }
    }
}

// MARK: - Card Container

/// 卡片容器修饰器：白色背景、12pt 圆角、阴影、16pt 水平内边距
extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .padding(.horizontal, 16)
    }
}

// MARK: - Enhance Banner

/// AI 趣味解读横幅：打字机动画逐字展示
struct EnhanceBanner: View {
    let text: String
    let onDismiss: () -> Void

    @State private var displayedCount = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("趣味解读")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)

                Text(String(text.prefix(displayedCount)))
                    .font(.system(size: 13))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            startTypewriter()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startTypewriter() {
        displayedCount = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { t in
            if displayedCount < text.count {
                displayedCount += 1
            } else {
                t.invalidate()
            }
        }
    }
}

// MARK: - Enhance Button

/// 趣味解读触发按钮
struct EnhanceButton: View {
    let isLoading: Bool
    let hasContent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                Text(hasContent ? "换一种" : "趣味解读")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Group {
                    if isLoading {
                        Capsule()
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    }
                }
            )
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}

// MARK: - Video Overlay

struct CardVideoOverlay: View {
    let isPlaying: Bool
    let isMuted: Bool
    let onTogglePlay: () -> Void
    let onToggleMute: () -> Void

    var body: some View {
        ZStack {
            // 渐变遮罩
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )

            // 播放按钮（未播放时显示）
            if !isPlaying {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }

            // 底部控制栏
            VStack {
                Spacer()
                HStack {
                    Button {
                        onTogglePlay()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())

                    Spacer()

                    Button {
                        onToggleMute()
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
    }
}
