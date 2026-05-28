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
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 80)

                Text(ad.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let summary = ad.aiSummary {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.purple.opacity(0.5))
                            .padding(.top, 1)
                        Text(summary)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.65))
                            .lineSpacing(3)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !ad.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ad.tags) { tag in
                                TagChipView(
                                    tag: tag,
                                    isHighlighted: tag.name == activeTagFilter,
                                    highlightColor: ad.channel.accentColor
                                ) { onTagTap(tag) }
                            }
                        }
                    }
                }

                HStack {
                    Text(ad.sponsor)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Constants.Colors.secondaryText)
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
            .padding(16)
            .background(.white)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }
}
