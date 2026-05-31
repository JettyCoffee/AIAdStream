import SwiftUI

struct SearchView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.hasConversation {
                    conversationView
                } else {
                    welcomeView
                }
            }
            .navigationTitle("AI 广告搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                if viewModel.hasConversation {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("新对话") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                viewModel.clearConversation()
                            }
                        }
                        .font(.system(size: 14))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showHistory) {
                ConversationHistoryView { record in
                    viewModel.loadConversation(record)
                }
            }
        }
    }

    // MARK: - Welcome (initial state)

    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.blue.opacity(0.6))

                Text("描述你想看的广告")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 24)

            searchInputBar
                .padding(.horizontal, Constants.horizontalPadding)

            VStack(spacing: 10) {
                Text("试试这样说")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Constants.Colors.secondaryText)
                    .padding(.top, 32)

                suggestionsGrid
            }
            .padding(.horizontal, Constants.horizontalPadding)

            Spacer()
        }
    }

    private var suggestionsGrid: some View {
        let suggestions: [(String, String)] = [
            ("🏃", "适合学生党的运动品牌"),
            ("💻", "数码产品优惠活动"),
            ("🍜", "本地美食探店推荐"),
            ("💄", "性价比高的护肤品"),
            ("👔", "上班族通勤穿搭推荐"),
            ("🎮", "适合送礼的创意好物"),
        ]

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(suggestions, id: \.1) { emoji, text in
                Button {
                    viewModel.inputText = text
                    viewModel.sendMessage()
                } label: {
                    HStack(spacing: 6) {
                        Text(emoji)
                            .font(.system(size: 13))
                        Text(text)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Conversation

    private var conversationView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // 按顺序渲染所有对话项：消息气泡 / 广告卡片
                        ForEach(viewModel.items) { item in
                            switch item {
                            case .message(let msg):
                                chatBubble(msg)
                            case .adCards(let ads):
                                adCardsInline(ads)
                            }
                        }

                        // 流式输出中：显示正在生成的文本
                        if viewModel.isStreaming {
                            streamingBubble
                        }

                        // 错误提示
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        // 滚动锚点
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, Constants.horizontalPadding)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.streamingContent) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.items.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.isStreaming) { _, newValue in
                    if !newValue {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            searchInputBar
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Circle())
                    .padding(.top, 2)
            } else {
                Spacer(minLength: 40)
            }

            Text(msg.content)
                .font(.system(size: 15))
                .foregroundColor(msg.role == .user ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    msg.role == .user
                        ? Color.blue
                        : Color(red: 0.95, green: 0.95, blue: 0.96)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if msg.role == .user {
                Spacer(minLength: 40)
            }
        }
    }

    @ViewBuilder
    private var streamingBubble: some View {
        let content = viewModel.streamingContent.isEmpty ? "..." : viewModel.streamingContent
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(.blue)
                .padding(6)
                .background(Color.blue.opacity(0.08))
                .clipShape(Circle())
                .padding(.top, 2)

            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.primary.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.95, green: 0.95, blue: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 2) {
                        Circle().fill(.blue.opacity(0.5)).frame(width: 5, height: 5)
                        Circle().fill(.blue.opacity(0.5)).frame(width: 5, height: 5)
                        Circle().fill(.blue.opacity(0.5)).frame(width: 5, height: 5)
                    }
                    .padding(.trailing, -20)
                    .padding(.bottom, -4)
                }

            Spacer(minLength: 40)
        }
    }

    // MARK: - Ad Cards (inline, between messages)

    private func adCardsInline(_ ads: [AdItem]) -> some View {
        VStack(spacing: 8) {
            ForEach(ads) { ad in
                NavigationLink {
                    AdDetailView(ad: ad)
                        .environmentObject(feedViewModel)
                } label: {
                    adCardRow(ad)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 32)
    }

    private func adCardRow(_ ad: AdItem) -> some View {
        HStack(spacing: 12) {
            LazyImageView(imageName: ad.imageURL, contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .background(Color.gray.opacity(0.05))

            VStack(alignment: .leading, spacing: 4) {
                Text(ad.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(ad.sponsor)
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.secondaryText)

                Text(ad.description)
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Constants.Colors.secondaryText)
        }
        .padding(10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Search Input Bar

    private var searchInputBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Constants.Colors.secondaryText)

                TextField("描述你想看的广告...", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        viewModel.sendMessage()
                    }
                    .lineLimit(1...4)

                if !viewModel.inputText.isEmpty {
                    Button {
                        viewModel.inputText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.95, green: 0.95, blue: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(
                        viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gray.opacity(0.3)
                            : Color.blue
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
