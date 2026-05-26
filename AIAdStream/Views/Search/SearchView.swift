import SwiftUI

struct SearchView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Constants.Colors.secondaryText)
                        TextField("描述你想看的广告...", text: $viewModel.query)
                            .font(.system(size: 15))
                            .focused($isFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await viewModel.search() }
                            }
                        if !viewModel.query.isEmpty {
                            Button {
                                viewModel.query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Constants.Colors.secondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.95, green: 0.95, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("搜索") {
                        isFocused = false
                        Task { await viewModel.search() }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, 10)

                Divider()

                if viewModel.isSearching {
                    Spacer()
                    ProgressView("搜索中...")
                        .foregroundColor(Constants.Colors.secondaryText)
                    Spacer()
                } else if viewModel.hasSearched && viewModel.results.isEmpty {
                    emptyResultView
                } else if viewModel.hasSearched {
                    resultListView
                } else {
                    suggestionView
                }
            }
            .navigationTitle("对话式搜索")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { isFocused = true }
        }
    }

    private var resultListView: some View {
        ScrollView {
            LazyVStack(spacing: Constants.cardSpacing) {
                Text("找到 \(viewModel.results.count) 条结果")
                    .font(.system(size: 13))
                    .foregroundColor(Constants.Colors.secondaryText)
                    .padding(.top, 8)

                ForEach(viewModel.results) { ad in
                    NavigationLink {
                        AdDetailView(ad: ad)
                            .environmentObject(feedViewModel)
                    } label: {
                        AdCardView(
                            ad: ad,
                            interactionState: Binding(
                                get: { feedViewModel.interactionState(for: ad.id) },
                                set: { feedViewModel.interactionStates[ad.id] = $0 }
                            ),
                            onLike: { feedViewModel.toggleLike(for: ad.id) },
                            onCollect: { feedViewModel.toggleCollect(for: ad.id) },
                            onShare: { feedViewModel.incrementShare(for: ad.id) },
                            onTagTap: { _ in },
                            isActive: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var emptyResultView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Constants.Colors.secondaryText)
            Text("未找到匹配的广告")
                .font(.system(size: 16))
                .foregroundColor(Constants.Colors.secondaryText)
            Text("尝试换一种描述方式")
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.secondaryText.opacity(0.7))
            Spacer()
        }
    }

    private var suggestionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("试试这样说：")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Constants.Colors.secondaryText)
                .padding(.top, 24)
                .padding(.horizontal, Constants.horizontalPadding)

            VStack(spacing: 10) {
                ForEach([
                    "适合学生党的运动品牌",
                    "数码产品优惠活动",
                    "本地美食探店推荐",
                    "性价比高的护肤品",
                ], id: \.self) { suggestion in
                    Button {
                        viewModel.query = suggestion
                        Task { await viewModel.search() }
                    } label: {
                        HStack {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 13))
                                .foregroundColor(.blue.opacity(0.7))
                            Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 11))
                                .foregroundColor(Constants.Colors.secondaryText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Constants.horizontalPadding)
                }
            }

            Spacer()
        }
    }
}
