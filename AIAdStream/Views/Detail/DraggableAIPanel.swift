import SwiftUI

// MARK: - Panel State

enum AIPanelState: CGFloat, CaseIterable {
    case bar    = 0
    case medium = 1
    case large  = 2

    func height(in geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        switch self {
        case .bar:    return 72
        case .medium: return screenHeight * 0.38
        case .large:  return screenHeight * 0.78
        }
    }

    var dragIndicatorVisible: Bool {
        self != .bar
    }
}

// MARK: - Draggable AI Panel

struct DraggableAIPanel: View {
    let ad: AdItem
    @ObservedObject var viewModel: DetailViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    @Binding var panelState: AIPanelState

    @State private var dragOffset: CGFloat = 0
    @FocusState private var isChatFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let currentHeight = panelState.height(in: geometry) + dragOffset

            VStack(spacing: 0) {
                // 拖拽指示条
                if panelState != .bar || dragOffset < -10 {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.35))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                if panelState == .bar && dragOffset >= 0 {
                    compactBar
                } else {
                    expandedChat
                }
            }
            .frame(height: max(currentHeight, 60))
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(panelState == .bar ? 0.08 : 0.18), radius: 10, y: -4)
            .offset(y: offsetForState(in: geometry))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.height
                        // 阻力感：拖动超过边界时施加阻尼
                        if panelState == .bar && translation > 0 {
                            dragOffset = translation * 0.3
                        } else if panelState == .large && translation < 0 {
                            dragOffset = translation * 0.3
                        } else {
                            dragOffset = translation
                        }
                    }
                    .onEnded { value in
                        snapToNearestState(velocity: value.predictedEndTranslation.height - value.translation.height)
                    }
            )
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: panelState)
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: dragOffset)
        }
    }

    // MARK: - Offset

    private func offsetForState(in geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let panelHeight = panelState.height(in: geometry) + dragOffset
        // 面板底部对齐屏幕底部
        return screenHeight - panelHeight
    }

    // MARK: - Compact Bar

    private var compactBar: some View {
        VStack(spacing: 8) {
            let interactionBinding = Binding(
                get: { feedViewModel.interactionState(for: ad.id) },
                set: { feedViewModel.interactionStates[ad.id] = $0 }
            )
            InteractionBar(
                adId: ad.id,
                state: interactionBinding,
                onLike: { feedViewModel.toggleLike(for: ad.id) },
                onCollect: { feedViewModel.toggleCollect(for: ad.id) },
                onShare: { feedViewModel.incrementShare(for: ad.id) }
            )

            // AI 输入提示
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.purple.opacity(0.6))
                Text("咨询 AI 助手了解更多...")
                    .font(.system(size: 14))
                    .foregroundColor(Constants.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onTapGesture {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    panelState = .medium
                }
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, 10)
    }

    // MARK: - Expanded Chat

    private var expandedChat: some View {
        VStack(spacing: 0) {
            // 顶栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundColor(.purple)
                    Text("AI 助手")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                }
                Spacer()
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                        panelState = .bar
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, 10)

            Divider()

            // 消息列表
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
    }

    // MARK: - Chat Sub-Views

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

    private func errorBanner(_ error: String) -> some View {
        Text(error)
            .font(.system(size: 12))
            .foregroundColor(.orange)
            .padding(8)
            .background(Color.orange.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

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

    // MARK: - Drag Snapping

    private func snapToNearestState(velocity: CGFloat) {
        defer { dragOffset = 0 }

        let fastSwipeThreshold: CGFloat = 300

        if velocity < -fastSwipeThreshold {
            // 快速上滑
            if panelState == .bar { panelState = .medium }
            else if panelState == .medium { panelState = .large }
            return
        }
        if velocity > fastSwipeThreshold {
            // 快速下滑
            if panelState == .large { panelState = .medium }
            else if panelState == .medium { panelState = .bar }
            return
        }

        // 慢速拖动：基于位移阈值判断
        let threshold: CGFloat = 40
        switch panelState {
        case .bar:
            if dragOffset < -threshold { panelState = .medium }
        case .medium:
            if dragOffset < -threshold { panelState = .large }
            else if dragOffset > threshold { panelState = .bar }
        case .large:
            if dragOffset > threshold { panelState = .medium }
        }
    }
}
