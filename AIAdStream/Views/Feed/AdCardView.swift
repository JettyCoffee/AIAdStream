import SwiftUI

struct AdCardView: View {
    let ad: AdItem
    @Binding var interactionState: InteractionState
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    let isActive: Bool

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
                    onTagTap: onTagTap
                )
            case .smallImage:
                SmallImageCard(
                    ad: ad,
                    interactionState: $interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare,
                    onTagTap: onTagTap
                )
            case .video:
                VideoCard(
                    ad: ad,
                    interactionState: $interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare,
                    onTagTap: onTagTap,
                    isActive: isActive
                )
            }
        }
    }
}
