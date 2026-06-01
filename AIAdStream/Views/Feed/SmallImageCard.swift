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

            CardInfoSectionCompact(
                ad: ad,
                interactionState: interactionState,
                onLike: onLike,
                onCollect: onCollect,
                onShare: onShare,
                onTagTap: onTagTap,
                activeTagFilter: activeTagFilter
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .cardStyle()
    }
}
