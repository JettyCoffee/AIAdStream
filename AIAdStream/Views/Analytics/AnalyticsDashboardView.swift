import SwiftUI

struct AnalyticsDashboardView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overviewCards
                    periodPicker

                    if viewModel.totalEvents > 0 {
                        eventDistributionSection
                        channelSection
                        topAdsSection

                        if !viewModel.stateChanges.isEmpty {
                            stateChangeSection
                        }

                        recentEventsSection
                    } else {
                        emptyState
                    }
                }
                .padding(Constants.horizontalPadding)
                .padding(.bottom, 32)
            }
            .background(Color(red: 0.97, green: 0.97, blue: 0.97))
            .navigationTitle("数据看板")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.4))
            Text("暂无数据")
                .font(.system(size: 16))
                .foregroundColor(Constants.Colors.secondaryText)
            Text("开始浏览广告后，数据将自动统计至此")
                .font(.system(size: 13))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Overview

    private var overviewCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 8) {
            StatCard(title: "曝光", value: "\(viewModel.impressions)", color: .blue, icon: "eye")
            StatCard(title: "点击", value: "\(viewModel.clicks)", color: .green, icon: "hand.tap")
            StatCard(title: "CTR", value: String(format: "%.1f%%", viewModel.ctr), color: .orange, icon: "arrow.up.right")
            StatCard(title: "点赞", value: "\(viewModel.likes)", color: .pink, icon: "heart")
            StatCard(title: "收藏", value: "\(viewModel.collects)", color: .purple, icon: "bookmark")
            StatCard(title: "分享", value: "\(viewModel.shares)", color: .indigo, icon: "square.and.arrow.up")
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("时间范围", selection: $viewModel.selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedPeriod) {
            viewModel.refresh()
        }
    }

    // MARK: - Event Distribution

    private var eventDistributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("事件分布", icon: "chart.bar.fill")

            let maxCount = max(1, viewModel.eventTypeBreakdown.first?.count ?? 1)
            ForEach(viewModel.eventTypeBreakdown, id: \.type.rawValue) { item in
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: iconForEvent(item.type))
                                .font(.system(size: 11))
                                .foregroundColor(colorForEvent(item.type))
                            Text(eventTypeLabel(item.type))
                                .font(.system(size: 13))
                        }
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    let ratio = CGFloat(item.count) / CGFloat(maxCount)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForEvent(item.type).opacity(0.3))
                            .frame(width: max(geo.size.width * ratio, 4), height: 6)
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - Channel Breakdown

    private var channelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("渠道分布", icon: "square.grid.2x2")

            let maxImp = max(1, viewModel.channelBreakdown.first?.impressions ?? 1)
            ForEach(viewModel.channelBreakdown, id: \.channel) { stats in
                VStack(spacing: 6) {
                    HStack {
                        Circle()
                            .fill(channelColor(stats.channel))
                            .frame(width: 8, height: 8)
                        Text(channelLabel(stats.channel))
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("曝光\(stats.impressions) · 点击\(stats.clicks) · 互动\(stats.likes + stats.collects + stats.shares)")
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(channelColor(stats.channel).opacity(0.25))
                            .frame(width: max(geo.size.width * CGFloat(stats.impressions) / CGFloat(maxImp), 4), height: 6)
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - Top Ads

    private var topAdsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("互动排行", icon: "trophy")

            ForEach(Array(viewModel.topAds.enumerated()), id: \.offset) { index, adInfo in
                HStack(spacing: 10) {
                    rankBadge(index)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(adInfo.adTitle)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Text(adInfo.adSponsor)
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        if let likeCount = adInfo.breakdown[.like] {
                            eventCountBadge(count: likeCount, icon: "heart", color: .pink)
                        }
                        if let collectCount = adInfo.breakdown[.collect] {
                            eventCountBadge(count: collectCount, icon: "bookmark", color: .purple)
                        }
                        Text("\(adInfo.count) 次")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - State Change Log

    private var stateChangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("状态变更日志", icon: "clock.arrow.2.circlepath")

            ForEach(viewModel.stateChanges.prefix(10)) { event in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 10))
                        .foregroundColor(.teal)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 3) {
                        if let sc = event.stateChange {
                            HStack(spacing: 4) {
                                Text("「\(event.adTitle ?? event.adId ?? "")」")
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(stateChangeSummary(sc))
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                        } else {
                            Text(event.displayText)
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }
                        Text(formatTimestamp(event.timestamp))
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }

                    Spacer()

                    if let channel = event.channel {
                        Text(channelLabel(channel))
                            .font(.system(size: 10))
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
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - Recent Events

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("最近事件", icon: "list.bullet.rectangle")

            ForEach(viewModel.enrichedEvents.prefix(20)) { event in
                HStack(spacing: 8) {
                    Image(systemName: iconForEvent(event.type))
                        .font(.system(size: 11))
                        .foregroundColor(colorForEvent(event.type))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.displayText)
                            .font(.system(size: 13))
                            .lineLimit(1)

                        Text(formatTimestamp(event.timestamp))
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }

                    Spacer()

                    if let channel = event.channel {
                        Text(channelLabel(channel))
                            .font(.system(size: 10))
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
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private func rankBadge(_ index: Int) -> some View {
        Text("\(index + 1)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(rankColor(index))
            .clipShape(Circle())
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .gray.opacity(0.7)
        case 2: return .brown.opacity(0.7)
        default: return .gray.opacity(0.4)
        }
    }

    private func eventCountBadge(count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text("\(count)")
                .font(.system(size: 11))
        }
        .foregroundColor(color)
    }

    // MARK: - Helpers

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
        case .stateChange: return "arrow.triangle.swap"
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
        case .stateChange: return .teal
        }
    }

    private func eventTypeLabel(_ type: AnalyticsEventType) -> String {
        switch type {
        case .impression: return "曝光"
        case .click: return "点击"
        case .like: return "点赞"
        case .collect: return "收藏"
        case .share: return "分享"
        case .search: return "搜索"
        case .tagClick: return "标签点击"
        case .stateChange: return "状态变更"
        }
    }

    private func stateChangeSummary(_ sc: StateChangeInfo) -> String {
        let fieldName: String
        switch sc.field {
        case "isLiked": fieldName = "点赞"
        case "isCollected": fieldName = "收藏"
        case "likeCount": fieldName = "点赞数"
        case "shareCount": fieldName = "分享数"
        default: fieldName = sc.field
        }
        let fromDisplay: String
        let toDisplay: String
        switch sc.field {
        case "isLiked", "isCollected":
            fromDisplay = sc.from == "true" ? "是" : "否"
            toDisplay = sc.to == "true" ? "是" : "否"
        default:
            fromDisplay = sc.from
            toDisplay = sc.to
        }
        return "\(fieldName): \(fromDisplay) → \(toDisplay)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm:ss"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "昨天 HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(color.opacity(0.7))
                }
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(Constants.Colors.secondaryText)
            }
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
