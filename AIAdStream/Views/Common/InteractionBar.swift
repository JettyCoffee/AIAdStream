import SwiftUI

struct InteractionBar: View {
    let adId: String
    @Binding var state: InteractionState
    var onLike: (() -> Void)?
    var onCollect: (() -> Void)?
    var onShare: (() -> Void)?

    @State private var likeScale: CGFloat = 1.0
    @State private var collectScale: CGFloat = 1.0
    @State private var shareScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 20) {
            // 点赞
            Button {
                onLike?()
                triggerSpring($likeScale)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: state.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(state.isLiked ? Constants.Colors.likeActive : .primary.opacity(0.45))
                        .scaleEffect(likeScale)
                    Text("\(state.likeCount)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.45))
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // 收藏
            Button {
                onCollect?()
                triggerSpring($collectScale)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: state.isCollected ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundColor(state.isCollected ? .orange : .primary.opacity(0.45))
                        .scaleEffect(collectScale)
                    Text("\(state.isCollected ? 1 : 0)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.45))
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // 分享
            Button {
                onShare?()
                triggerSpring($shareScale)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 16))
                        .foregroundColor(.primary.opacity(0.45))
                        .scaleEffect(shareScale)
                    Text("\(state.shareCount)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.45))
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    private func triggerSpring(_ scale: Binding<CGFloat>) {
        scale.wrappedValue = 1.3
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            scale.wrappedValue = 1.0
        }
    }
}
