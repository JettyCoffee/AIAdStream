import SwiftUI

struct SmallImageCard: View {
    let ad: AdItem
    let interactionState: Binding<InteractionState>
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    var activeTagFilter: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(ad.sponsor)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Constants.Colors.secondaryText)

                Text(ad.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                Text(ad.aiSummary)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.55))
                    .lineLimit(2)

                if !ad.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ad.tags.prefix(3)) { tag in
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }
}
