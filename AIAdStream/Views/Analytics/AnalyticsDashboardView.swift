import SwiftUI

struct AnalyticsDashboardView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewCards

                if !viewModel.channelBreakdown.isEmpty {
                    channelSection
                }

                if !viewModel.topAds.isEmpty {
                    topAdsSection
                }

                if !viewModel.events.isEmpty {
                    recentEventsSection
                }
            }
            .padding(Constants.horizontalPadding)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.97))
        .navigationTitle("数据看板")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 10) {
            StatCard(
                title: "曝光",
                value: "\(viewModel.impressions)",
                color: .blue
            )
            StatCard(
                title: "点击",
                value: "\(viewModel.clicks)",
                color: .green
            )
            StatCard(
                title: "CTR",
                value: String(format: "%.1f%%", viewModel.ctr),
                color: .orange
            )
            StatCard(
                title: "总事件",
                value: "\(viewModel.events.count)",
                color: .purple
            )
        }
    }

    private var channelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("渠道分布")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 8)

            ForEach(viewModel.channelBreakdown, id: \.channel) { item in
                VStack(spacing: 6) {
                    HStack {
                        Text(channelLabel(item.channel))
                            .font(.system(size: 14))
                        Spacer()
                        Text("曝光 \(item.impressions) · 点击 \(item.clicks)")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }

                    let maxImpressions = max(1, viewModel.channelBreakdown.first?.impressions ?? 1)
                    let ratio = CGFloat(item.impressions) / CGFloat(maxImpressions)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(channelColor(item.channel))
                            .frame(width: geo.size.width * ratio, height: 6)
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private var topAdsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("互动排行")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 8)

            ForEach(Array(viewModel.topAds.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(index < 3 ? Color.orange : Color.gray.opacity(0.5))
                        .clipShape(Circle())

                    Text(item.adId)
                        .font(.system(size: 13))
                        .lineLimit(1)

                    Spacer()

                    Text("\(item.count) 次互动")
                        .font(.system(size: 12))
                        .foregroundColor(Constants.Colors.secondaryText)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近事件")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 8)

            ForEach(viewModel.events.suffix(20).reversed()) { event in
                HStack {
                    Image(systemName: iconForEvent(event.type))
                        .font(.system(size: 12))
                        .foregroundColor(colorForEvent(event.type))
                        .frame(width: 24)

                    Text(event.type.rawValue)
                        .font(.system(size: 13))

                    Spacer()

                    if let channel = event.channel {
                        Text(channelLabel(channel))
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Constants.Colors.tagBackground)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func channelLabel(_ raw: String) -> String {
        Channel.allCases.first { $0.rawValue == raw }?.displayName ?? raw
    }

    private func channelColor(_ raw: String) -> Color {
        Channel.allCases.first { $0.rawValue == raw }?.accentColor ?? .gray
    }

    private func iconForEvent(_ type: AnalyticsEventType) -> String {
        switch type {
        case .impression: return "eye"
        case .click: return "hand.tap"
        case .like: return "heart"
        case .collect: return "bookmark"
        case .share: return "square.and.arrow.up"
        case .search: return "magnifyingglass"
        case .tagClick: return "tag"
        }
    }

    private func colorForEvent(_ type: AnalyticsEventType) -> Color {
        switch type {
        case .impression: return .blue
        case .click: return .green
        case .like: return .pink
        case .collect: return .orange
        case .share: return .purple
        case .search: return .indigo
        case .tagClick: return .teal
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Constants.Colors.secondaryText)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
