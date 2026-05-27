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
            ZStack(alignment: .bottomLeading) {
                LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                    .frame(height: 220)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ad.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(ad.sponsor)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.bottom, 12)
            }

            VStack(alignment: .leading, spacing: 8) {
                TagRow(
                    tags: ad.tags,
                    highlightedTagName: activeTagFilter,
                    highlightColor: ad.channel.accentColor,
                    onTagTap: onTagTap
                )
                .padding(.top, 8)

                if let summary = ad.aiSummary {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundColor(Constants.Colors.secondaryText)
                        .lineLimit(2)
                        .padding(.horizontal, Constants.horizontalPadding)
                }

                InteractionBar(
                    adId: ad.id,
                    state: interactionState,
                    onLike: onLike,
                    onCollect: onCollect,
                    onShare: onShare
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, 8)
            }
            .padding(.bottom, 4)
            .background(.white)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal, Constants.horizontalPadding)
    }
}
