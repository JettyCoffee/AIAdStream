import SwiftUI

struct SmallImageCard: View {
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
            HStack(alignment: .top, spacing: 12) {
                LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        .cardStyle()
    }
}
