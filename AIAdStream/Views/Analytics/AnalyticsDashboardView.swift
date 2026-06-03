import SwiftUI

struct AnalyticsDashboardView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    creatorHeader
                    periodPicker
                    kpiGrid
                    trendSection
                    channelSection
                    topAdsSection
                    myAdsSection
                }
                .padding(Constants.horizontalPadding)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("数据中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showUploadSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showUploadSheet) {
                uploadAdSheet
            }
            .onAppear { viewModel.refresh() }
            .onChange(of: viewModel.selectedPeriod) { _, _ in viewModel.refresh() }
        }
    }

    // MARK: - Creator Header

    private var creatorHeader: some View {
        HStack(spacing: 14) {
            // 头像
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("广告创作者")
                    .font(.system(size: 16, weight: .bold))
                Text("广告投放数据与效果分析")
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.secondaryText)
            }

            Spacer()

            // 快捷创建按钮
            Button {
                viewModel.showUploadSheet = true
            } label: {
                Text("创建广告")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack {
            Picker("时间范围", selection: $viewModel.selectedPeriod) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - KPI Grid

    private var kpiGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ], spacing: 10) {
            KPICard(
                title: "曝光量",
                value: "\(viewModel.impressions)",
                icon: "eye.fill",
                color: .blue
            )
            KPICard(
                title: "点击量",
                value: "\(viewModel.clicks)",
                icon: "hand.tap.fill",
                color: .green
            )
            KPICard(
                title: "点击率",
                value: String(format: "%.1f%%", viewModel.ctr),
                icon: "arrow.up.right",
                color: .orange
            )
            KPICard(
                title: "互动量",
                value: "\(viewModel.totalInteractions)",
                icon: "heart.fill",
                color: .pink
            )
            KPICard(
                title: "互动率",
                value: String(format: "%.1f%%", viewModel.engagementRate),
                icon: "hand.thumbsup.fill",
                color: .purple
            )
            KPICard(
                title: "分享数",
                value: "\(viewModel.shares)",
                icon: "square.and.arrow.up.fill",
                color: .indigo
            )
        }
    }

    // MARK: - Trend Section

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("效果趋势", icon: "chart.xyaxis.line")

            if viewModel.dailyTrend.isEmpty {
                emptyChartPlaceholder
            } else {
                TrendChart(data: viewModel.dailyTrend)
                    .frame(height: 160)

                // 图例
                HStack(spacing: 24) {
                    legendItem(color: .blue, label: "曝光")
                    legendItem(color: .green, label: "点击")
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.3))
            Text("暂无趋势数据")
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Constants.Colors.secondaryText)
        }
    }

    // MARK: - Channel Section

    private var channelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("渠道分布", icon: "square.grid.2x2")

            if viewModel.channelSummaries.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无渠道数据")
                        .font(.system(size: 13))
                        .foregroundColor(Constants.Colors.secondaryText)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                let maxImp = max(1, viewModel.channelSummaries.first?.impressions ?? 1)

                ForEach(viewModel.channelSummaries) { summary in
                    channelRow(summary, maxImp: maxImp)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private func channelRow(_ summary: ChannelSummary, maxImp: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(channelColor(summary.channel))
                    .frame(width: 10, height: 10)
                Text(channelLabel(summary.channel))
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                HStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(summary.impressions)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        Text("曝光")
                            .font(.system(size: 10))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.1f%%", summary.ctr))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("CTR")
                            .font(.system(size: 10))
                            .foregroundColor(Constants.Colors.secondaryText)
                    }
                }
            }

            // 比例条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray6))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(channelColor(summary.channel).opacity(0.6))
                        .frame(
                            width: max(geo.size.width * CGFloat(summary.impressions) / CGFloat(maxImp), 4),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Top Ads Section

    private var topAdsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("广告排行 TOP5", icon: "trophy.fill")

            if viewModel.topAds.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无排行数据")
                        .font(.system(size: 13))
                        .foregroundColor(Constants.Colors.secondaryText)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                let maxCount = max(1, viewModel.topAds.first?.count ?? 1)

                ForEach(Array(viewModel.topAds.enumerated()), id: \.element.id) { index, adInfo in
                    topAdRow(adInfo, rank: index + 1, maxCount: maxCount)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private func topAdRow(_ adInfo: TopAdInfo, rank: Int, maxCount: Int) -> some View {
        let isExpanded = viewModel.expandedTopAdId == adInfo.adId

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.expandedTopAdId = isExpanded ? nil : adInfo.adId
                }
            } label: {
                HStack(spacing: 10) {
                    // 排名
                    rankBadge(rank)

                    // 信息
                    VStack(alignment: .leading, spacing: 2) {
                        Text(adInfo.adTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(adInfo.adSponsor)
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 曝光量和比例条
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(adInfo.count)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                            Text("事件")
                                .font(.system(size: 10))
                                .foregroundColor(Constants.Colors.secondaryText)
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(rankColor(rank).opacity(0.3))
                                .frame(
                                    width: max(geo.size.width * CGFloat(adInfo.count) / CGFloat(maxCount), 4),
                                    height: 4
                                )
                        }
                        .frame(width: 60, height: 4)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 展开详情
            if isExpanded {
                VStack(spacing: 8) {
                    Divider().opacity(0.5)
                    HStack(spacing: 12) {
                        expandedStat("曝光", adInfo.breakdown[.impression] ?? 0, .blue)
                        expandedStat("点击", adInfo.breakdown[.click] ?? 0, .green)
                        expandedStat("CTR", ctrString(adInfo), .orange)
                        expandedStat("点赞", adInfo.breakdown[.like] ?? 0, .pink)
                        expandedStat("收藏", adInfo.breakdown[.collect] ?? 0, .purple)
                        expandedStat("分享", adInfo.breakdown[.share] ?? 0, .indigo)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                }
            }

            if rank < viewModel.topAds.count {
                Divider().opacity(0.3)
            }
        }
    }

    private func ctrString(_ adInfo: TopAdInfo) -> String {
        let imp = adInfo.breakdown[.impression] ?? 0
        let click = adInfo.breakdown[.click] ?? 0
        guard imp > 0 else { return "-" }
        return String(format: "%.1f%%", Double(click) / Double(imp) * 100)
    }

    private func expandedStat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Constants.Colors.secondaryText)
        }
    }

    private func expandedStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Constants.Colors.secondaryText)
        }
    }

    // MARK: - My Ads Section

    private var myAdsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("我的广告", icon: "megaphone.fill")
                Spacer()
                Text("\(viewModel.userAdCount) 条投放中")
                    .font(.system(size: 12))
                    .foregroundColor(.blue.opacity(0.7))
            }

            if viewModel.userAds.isEmpty {
                emptyMyAds
            } else {
                ForEach(viewModel.userAds) { ad in
                    userAdCard(ad)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private var emptyMyAds: some View {
        VStack(spacing: 12) {
            Image(systemName: "megaphone")
                .font(.system(size: 28))
                .foregroundColor(.blue.opacity(0.3))
            VStack(spacing: 4) {
                Text("还没有投放广告")
                    .font(.system(size: 14, weight: .medium))
                Text("点击右上角 + 创建你的第一条广告")
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.secondaryText)
            }
            Button {
                viewModel.showUploadSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("创建广告")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func userAdCard(_ ad: UserAd) -> some View {
        let stats = viewModel.statsForUserAd(ad)
        let maxStat = max(1, max(stats.impressions, stats.clicks, stats.likes, stats.collects, stats.shares))

        return VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ad.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(ad.sponsor)
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                        if let channel = Channel(rawValue: ad.channel) {
                            Text("·")
                                .foregroundColor(Constants.Colors.secondaryText)
                            Text(channel.displayName)
                                .font(.system(size: 11))
                                .foregroundColor(channel.accentColor)
                        }
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        viewModel.deleteUserAd(ad)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.5))
                }
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
            }

            // 标签
            if !ad.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ad.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.primary.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Constants.Colors.tagBackground)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // 迷你横向指标条
            VStack(spacing: 6) {
                miniBarRow(label: "曝光", value: stats.impressions, color: .blue, maxValue: maxStat)
                miniBarRow(label: "点击", value: stats.clicks, color: .green, maxValue: maxStat)
                miniBarRow(label: "点赞", value: stats.likes, color: .pink, maxValue: maxStat)
                miniBarRow(label: "收藏", value: stats.collects, color: .orange, maxValue: maxStat)
                miniBarRow(label: "分享", value: stats.shares, color: .purple, maxValue: maxStat)
            }

            // 时间
            HStack {
                Spacer()
                Text(formatDate(ad.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func miniBarRow(label: String, value: Int, color: Color, maxValue: Int) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Constants.Colors.secondaryText)
                .frame(width: 28, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray6))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.5))
                        .frame(
                            width: max(geo.size.width * CGFloat(value) / CGFloat(maxValue), 0),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
            Text("\(value)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary.opacity(0.6))
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Upload Sheet

    private var uploadAdSheet: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("广告标题", text: $viewModel.newAdTitle)
                    TextField("品牌/赞助商", text: $viewModel.newAdSponsor)
                }

                Section("广告描述") {
                    TextEditor(text: $viewModel.newAdDescription)
                        .frame(minHeight: 80)
                }

                Section("频道") {
                    Picker("频道", selection: $viewModel.newAdChannel) {
                        ForEach(viewModel.channelOptions, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("卡片类型") {
                    Picker("卡片类型", selection: $viewModel.newAdCardType) {
                        ForEach(viewModel.cardTypeOptions, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("标签（逗号分隔）") {
                    TextField("如: 科技, 潮流, 学生", text: $viewModel.newAdTagsText)
                }

                Section {
                    Button {
                        viewModel.uploadAd()
                    } label: {
                        HStack {
                            Spacer()
                            Text("发布广告")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                    }
                    .disabled(viewModel.newAdTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        || viewModel.newAdSponsor.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("创建广告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        viewModel.showUploadSheet = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text("\(rank)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(rank <= 3 ? .white : .secondary)
            .frame(width: 22, height: 22)
            .background(
                rank <= 3
                    ? rankColor(rank)
                    : Color(.systemGray5)
            )
            .clipShape(Circle())
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .orange
        case 2: return .gray
        case 3: return .brown.opacity(0.7)
        default: return .gray.opacity(0.3)
        }
    }

    private func channelLabel(_ raw: String) -> String {
        Channel.allCases.first { $0.rawValue == raw }?.displayName ?? raw
    }

    private func channelColor(_ raw: String) -> Color {
        Channel.allCases.first { $0.rawValue == raw }?.accentColor ?? .gray
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return "创建于 " + formatter.string(from: date)
    }
}

// MARK: - KPI Card

private struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(Constants.Colors.secondaryText)
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
    }
}

// MARK: - Trend Chart

private struct TrendChart: View {
    let data: [DailyTrendPoint]

    private let barSpacing: CGFloat = 3
    private let barCornerRadius: CGFloat = 2

    var body: some View {
        let maxValue = max(1, data.map { max($0.impressions, $0.clicks) }.max() ?? 1)

        GeometryReader { geo in
            let chartWidth = geo.size.width
            let chartHeight = geo.size.height - 20 // 留出底部标签空间
            let pairCount = data.count
            let pairSpacing: CGFloat = 4
            let pairWidth = pairCount > 1
                ? (chartWidth - pairSpacing * CGFloat(pairCount - 1)) / CGFloat(pairCount)
                : chartWidth
            let barTotalWidth = max(pairWidth - 2, 1)
            let singleBarWidth = max((barTotalWidth - barSpacing) / 2, 1)

            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // 网格线
                    VStack(spacing: chartHeight / 3) {
                        ForEach(0..<4) { _ in
                            Divider()
                                .opacity(0.15)
                            Spacer()
                        }
                    }
                    .frame(height: chartHeight)

                    // 柱状图
                    HStack(alignment: .bottom, spacing: pairSpacing) {
                        ForEach(data) { point in
                            HStack(spacing: barSpacing) {
                                // 曝光柱
                                RoundedRectangle(cornerRadius: barCornerRadius)
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(
                                        width: singleBarWidth,
                                        height: max(CGFloat(point.impressions) / CGFloat(maxValue) * chartHeight, point.impressions > 0 ? 3 : 0)
                                    )
                                // 点击柱
                                RoundedRectangle(cornerRadius: barCornerRadius)
                                    .fill(Color.green.opacity(0.6))
                                    .frame(
                                        width: singleBarWidth,
                                        height: max(CGFloat(point.clicks) / CGFloat(maxValue) * chartHeight, point.clicks > 0 ? 3 : 0)
                                    )
                            }
                            .frame(width: pairWidth)
                        }
                    }
                }
                .frame(height: chartHeight)

                // X轴标签
                HStack(spacing: pairSpacing) {
                    ForEach(data) { point in
                        Text(point.dateLabel)
                            .font(.system(size: 9))
                            .foregroundColor(Constants.Colors.secondaryText)
                            .lineLimit(1)
                            .frame(width: pairWidth)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
