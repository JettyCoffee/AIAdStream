import SwiftUI

struct InteractionBar: View {
    let adId: String
    @Binding var state: InteractionState
    var onLike: (() -> Void)?
    var onCollect: (() -> Void)?
    var onShare: (() -> Void)?

    @State private var likeScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 24) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    state.isLiked.toggle()
                    state.likeCount += state.isLiked ? 1 : -1
                }
                if state.isLiked {
                    likeScale = 1.5
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        likeScale = 1.0
                    }
                }
                onLike?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: state.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(state.isLiked ? Constants.Colors.likeActive : .primary.opacity(0.6))
                        .scaleEffect(likeScale)
                    if state.likeCount > 0 {
                        Text("\(state.likeCount)")
                            .font(.system(size: 13))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                }
                .font(.system(size: 16))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    state.isCollected.toggle()
                }
                onCollect?()
            } label: {
                Image(systemName: state.isCollected ? "bookmark.fill" : "bookmark")
                    .foregroundColor(state.isCollected ? .orange : .primary.opacity(0.6))
                    .font(.system(size: 16))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    state.shareCount += 1
                }
                onShare?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right")
                    if state.shareCount > 0 {
                        Text("\(state.shareCount)")
                            .font(.system(size: 13))
                    }
                }
                .font(.system(size: 16))
                .foregroundColor(.primary.opacity(0.6))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}
