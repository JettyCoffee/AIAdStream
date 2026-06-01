import SwiftUI

struct BigImageCard: View {
    let ad: AdItem
    let interactionState: Binding<InteractionState>
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void
    var activeTagFilter: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 大图区
            ZStack(alignment: .bottomLeading) {
                LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                    .frame(height: 220)
                    .clipped()

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
            CardInfoSection(
                ad: ad,
                interactionState: interactionState,
                onLike: onLike,
                onCollect: onCollect,
                onShare: onShare,
                onTagTap: onTagTap,
                activeTagFilter: activeTagFilter
            )
        }
        .cardStyle()
    }
}
