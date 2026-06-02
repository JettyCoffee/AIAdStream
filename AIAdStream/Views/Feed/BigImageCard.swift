import SwiftUI

struct BigImageCard: View {
    let ad: AdItem
    let interactionState: Binding<InteractionState>
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    var activeTagFilter: String?

    var enhancedContent: String? = nil
    var isEnhancing: Bool = false
    var onEnhance: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 大图区
            ZStack(alignment: .bottomLeading) {
                LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
                    .compositingGroup()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 80)

                CardTitleLabel(title: ad.title, lineLimit: 2)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // 信息区
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

                // 趣味解读
                if let content = enhancedContent {
                    EnhanceBanner(text: content) {
                        onEnhance?()
                    }
                }

                HStack {
                    CardSponsorLabel(sponsor: ad.sponsor)
                    Spacer()
                    EnhanceButton(
                        isLoading: isEnhancing,
                        hasContent: enhancedContent != nil,
                        action: { onEnhance?() }
                    )
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
    }
}
