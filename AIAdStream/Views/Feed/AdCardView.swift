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

    // 趣味解读
    var enhancedContent: String? = nil
    var isEnhancing: Bool = false
    var onEnhance: (() -> Void)? = nil

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
                    activeTagFilter: activeTagFilter,
                    enhancedContent: enhancedContent,
                    isEnhancing: isEnhancing,
                    onEnhance: onEnhance
                )
            case .smallImage:
                SmallImageCard(
                    ad: ad,
                    interactionState: $interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare,
                    onTagTap: onTagTap,
                    activeTagFilter: activeTagFilter,
                    enhancedContent: enhancedContent,
                    isEnhancing: isEnhancing,
                    onEnhance: onEnhance
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
                    activeTagFilter: activeTagFilter,
                    enhancedContent: enhancedContent,
                    isEnhancing: isEnhancing,
                    onEnhance: onEnhance
                )
            }
        }
    }
}
