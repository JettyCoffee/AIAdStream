import SwiftUI

struct SmallImageCard: View {
    let ad: AdItem
    let interactionState: Binding<InteractionState>
    let onLike: () -> Void
    let onCollect: () -> Void
    let onShare: () -> Void
    let onTagTap: (AITag) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(ad.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)

                Text(ad.description)
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.secondaryText)
                    .lineLimit(2)

                if let summary = ad.aiSummary {
                    Text(summary)
                        .font(.system(size: 11))
                        .foregroundColor(Constants.Colors.secondaryText)
                        .lineLimit(1)
                }

                if !ad.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ad.tags.prefix(3)) { tag in
                                TagChipView(tag: tag) { onTagTap(tag) }
                            }
                        }
                    }
                }

                HStack {
                    Text(ad.sponsor)
                        .font(.system(size: 11))
                        .foregroundColor(Constants.Colors.secondaryText)
                    Spacer()
                    InteractionBar(
                        adId: ad.id,
                        state: interactionState,
                        onLike: onLike,
                        onCollect: onCollect,
                        onShare: onShare
                    )
                    .scaleEffect(0.85)
                }
            }
        }
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal, Constants.horizontalPadding)
    }
}
