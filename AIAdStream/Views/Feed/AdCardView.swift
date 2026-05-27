import SwiftUI

struct AdCardView: View {
    let ad: AdItem
    @Binding var interactionState: InteractionState
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    let isActive: Bool
    var activeTagFilter: String?

    var body: some View {
        Group {
            switch ad.cardType {
            case .bigImage:
                BigImageCard(
                    ad: ad,
                    interactionState: $interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare,
                    onTagTap: onTagTap,
                    activeTagFilter: activeTagFilter
                )
            case .smallImage:
                SmallImageCard(
                    ad: ad,
                    interactionState: $interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare,
                    onTagTap: onTagTap,
                    activeTagFilter: activeTagFilter
                )
            case .video:
                VideoCard(
                    ad: ad,
                    interactionState: $interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare,
                    onTagTap: onTagTap,
                    isActive: isActive,
                    activeTagFilter: activeTagFilter
                )
            }
        }
    }
}
