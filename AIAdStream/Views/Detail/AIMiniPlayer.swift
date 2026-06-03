import SwiftUI

// MARK: - AI Mini Player (Liquid Glass)

/// 悬浮在详情页底部的 AI 助手迷你播放器，样式参考 Apple Music 播放控件
/// iOS 26+ 使用 Liquid Glass 效果，低版本使用 ultraThinMaterial 降级
struct AIMiniPlayer: View {
    let adTitle: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 10) {
                // 左侧图标
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
                }

                // 中间文字
                VStack(alignment: .leading, spacing: 1) {
                    Text("咨询 AI 助手")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text("关于「\(adTitle)」")
                        .font(.system(size: 11))
                        .foregroundColor(Constants.Colors.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                // 右侧展开箭头
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .glassBackground()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Chat Sheet Content

/// AI 聊天面板的 Sheet 内容
struct AIChatSheetContent: View {
    let ad: AdItem
    @ObservedObject var viewModel: DetailViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isChatFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // 标题栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                    Text("AI 助手")
                        .font(.system(size: 17, weight: .semibold))
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, 8)

            Divider()

            // 聊天消息区
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.chatMessages.isEmpty && !viewModel.isChatStreaming {
                            welcomePlaceholder
                        }

                        ForEach(viewModel.chatMessages) { msg in
                            chatBubble(msg)
                        }

                        if viewModel.isChatStreaming && !viewModel.chatStreamingContent.isEmpty {
                            streamingBubble
                        }

                        if !viewModel.chatRecommendedAds.isEmpty {
                            recommendedAdsSection
                        }

                        if let error = viewModel.chatErrorMessage {
                            errorBanner(error)
                        }

                        Color.clear.frame(height: 1).id("chatBottom")
                    }
                    .padding(Constants.horizontalPadding)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.chatStreamingContent) { _, _ in
                    withAnimation { proxy.scrollTo("chatBottom", anchor: .bottom) }
                }
                .onChange(of: viewModel.chatMessages.count) { _, _ in
                    withAnimation { proxy.scrollTo("chatBottom", anchor: .bottom) }
                }
            }

            Divider()

            // 底部输入栏
            chatInputBar
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Welcome

    private var welcomePlaceholder: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundColor(.purple)
                .padding(.top, 4)
            Text("我是你的广告智能助手，关于「\(ad.title)」有什么想了解的？")
                .font(.system(size: 14))
                .foregroundColor(.primary.opacity(0.7))
                .padding(10)
                .background(Color.purple.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Streaming

    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundColor(.purple)
                .padding(.top, 4)
            Text(viewModel.chatStreamingContent)
                .font(.system(size: 14))
                .foregroundColor(.primary.opacity(0.8))
                .padding(10)
                .background(Color.purple.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Recommended Ads

    private var recommendedAdsSection: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.chatRecommendedAds) { similarAd in
                NavigationLink {
                    AdDetailView(ad: similarAd)
                        .environmentObject(feedViewModel)
                } label: {
                    HStack(spacing: 10) {
                        LazyImageView(imageName: similarAd.imageURL, contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(similarAd.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text(similarAd.sponsor)
                                .font(.system(size: 11))
                                .foregroundColor(Constants.Colors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Error

    private func errorBanner(_ error: String) -> some View {
        Text(error)
            .font(.system(size: 12))
            .foregroundColor(.orange)
            .padding(8)
            .background(Color.orange.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            TextField("询问关于此广告...", text: $viewModel.chatInput, axis: .vertical)
                .font(.system(size: 14))
                .focused($isChatFocused)
                .submitLabel(.send)
                .onSubmit { viewModel.sendChatMessage() }
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                viewModel.sendChatMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(
                        viewModel.chatInput.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gray.opacity(0.3)
                            : Color.purple
                    )
            }
            .disabled(viewModel.chatInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if msg.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                    .padding(.top, 4)
            } else {
                Spacer()
            }

            Text(msg.content)
                .font(.system(size: 14))
                .foregroundColor(msg.role == .user ? .white : .primary.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    msg.role == .user
                        ? Color.purple.opacity(0.8)
                        : Color.purple.opacity(0.04)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Glass Background Modifier

private struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

extension View {
    /// 应用 Liquid Glass 背景效果（iOS 26+），低版本使用 regularMaterial 降级
    func glassBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }
}
