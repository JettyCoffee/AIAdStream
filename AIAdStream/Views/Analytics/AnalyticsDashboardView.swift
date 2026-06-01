import SwiftUI

struct AnalyticsDashboardView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 创作者信息头部
                creatorHeader

                // Tab 切换
                creatorTabSelector
                Divider()

                // 内容区
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch viewModel.selectedCreatorTab {
                        case .myAds:
                            myAdsTab
                        case .analytics:
                            analyticsTabContent
                        }
                    }
                    .padding(Constants.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(red: 0.97, green: 0.97, blue: 0.97))
            .navigationTitle("创作者中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.selectedCreatorTab == .myAds {
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
            }
            .sheet(isPresented: $viewModel.showUploadSheet) {
                uploadAdSheet
            }
            .onAppear { viewModel.refresh() }
        }
    }

    // MARK: - Creator Header

    private var creatorHeader: some View {
        VStack(spacing: 12) {
            // 头像和名称
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue, .purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)

                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("广告创作者")
                        .font(.system(size: 17, weight: .bold))
                    Text("管理你的广告投放与数据表现")
                        .font(.system(size: 12))
                        .foregroundColor(Constants.Colors.secondaryText)
                }

                Spacer()
            }

            // 数据概览
            HStack(spacing: 0) {
                headerStat(value: "\(viewModel.userAdCount)", label: "投放中", color: .blue)
                Divider().frame(height: 28)
                headerStat(value: "\(viewModel.userAdImpressions)", label: "曝光", color: .green)
                Divider().frame(height: 28)
                headerStat(value: "\(viewModel.userAdClicks)", label: "点击", color: .orange)
                Divider().frame(height: 28)
                headerStat(value: "\(viewModel.userAdInteractions)", label: "互动", color: .pink)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, 14)
        .background(.white)
    }

    private func headerStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Constants.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Creator Tab Selector

    private var creatorTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CreatorTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedCreatorTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: tab == .myAds ? "megaphone.fill" : "chart.bar.fill")
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(viewModel.selectedCreatorTab == tab ? .blue : .gray)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(viewModel.selectedCreatorTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2.5)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.white)
    }

    // MARK: - My Ads Tab

    private var myAdsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.userAds.isEmpty {
                emptyMyAds
            } else {
                ForEach(viewModel.userAds) { ad in
                    userAdCard(ad)
                }
            }
        }
    }

    private var emptyMyAds: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "megaphone")
                    .font(.system(size: 32))
                    .foregroundColor(.blue.opacity(0.4))
            }

            VStack(spacing: 6) {
                Text("还没有投放广告")
                    .font(.system(size: 16, weight: .medium))
                Text("点击右上角 + 开始创建你的第一条广告，\n查看广告数据表现")
                    .font(.system(size: 13))
                    .foregroundColor(Constants.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                viewModel.showUploadSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("创建广告")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func userAdCard(_ ad: UserAd) -> some View {
        let stats = viewModel.statsForUserAd(ad)

        return VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ad.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(ad.sponsor)
                        .font(.system(size: 12))
                        .foregroundColor(Constants.Colors.secondaryText)
                }

                Spacer()

                // 删除按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        viewModel.deleteUserAd(ad)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.6))
                }
                .frame(width: 32, height: 32)
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

            // 描述
            Text(ad.description)
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.5))
                .lineLimit(2)

            // 数据指标
            HStack(spacing: 20) {
                adMetric("曝光", stats.impressions, .blue)
                adMetric("点击", stats.clicks, .green)
                adMetric("点赞", stats.likes, .pink)
                adMetric("收藏", stats.collects, .orange)
                adMetric("分享", stats.shares, .purple)
                Spacer()
            }
            .padding(.top, 4)

            // 时间
            HStack {
                Spacer()
                Text(formatDate(ad.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func adMetric(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text("\(value)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Constants.Colors.secondaryText)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return "投放于 " + formatter.string(from: date)
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

    // MARK: - Analytics Tab (原有数据看板)

    private var analyticsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.totalEvents == 0 {
                analyticsEmptyState
            } else {
                analyticsInternalTabSelector
                Divider()

                switch viewModel.selectedTab {
                case .overview:
                    overviewTab
                case .content:
                    contentTab
                case .events:
                    eventsTab
                }
            }
        }
    }

    private var analyticsInternalTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: tabIcon(tab))
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(viewModel.selectedTab == tab ? .blue : .gray)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(viewModel.selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2.5)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.white)
    }

    private var analyticsEmptyState: some View {
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

    private func tabIcon(_ tab: AnalyticsTab) -> String {
        switch tab {
        case .overview: return "chart.pie.fill"
        case .content: return "list.bullet.rectangle"
        case .events: return "clock.arrow.2.circlepath"
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            overviewCards
            periodPicker
            eventDistributionSection
            channelSection
            topAdsSection
        }
    }

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

    private var periodPicker: some View {
        Picker("时间范围", selection: $viewModel.selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedPeriod) { viewModel.refresh() }
    }

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

    private var topAdsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("互动排行 TOP5", icon: "trophy")

            ForEach(Array(viewModel.topAds.enumerated()), id: \.offset) { index, adInfo in
                HStack(spacing: 10) {
                    rankBadge(index)

                    aidCapsule(adInfo.adId)

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

                    HStack(spacing: 10) {
                        if let imp = adInfo.breakdown[.impression] {
                            miniMetric("曝", imp)
                        }
                        if let likeCount = adInfo.breakdown[.like] {
                            miniMetric("赞", likeCount)
                        }
                        if let collectCount = adInfo.breakdown[.collect] {
                            miniMetric("藏", collectCount)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - Content Tab

    private var contentTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("全部广告", icon: "list.bullet.rectangle")
                Spacer()
                Text("\(viewModel.allAdsStats.count) 条")
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.secondaryText)
            }

            if viewModel.allAdsStats.isEmpty {
                VStack(spacing: 10) {
                    Spacer().frame(height: 20)
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("暂无广告数据")
                        .font(.system(size: 14))
                        .foregroundColor(Constants.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                HStack(spacing: 0) {
                    Text("AID")
                        .frame(width: 80, alignment: .leading)
                    Text("广告")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("曝光")
                        .frame(width: 42, alignment: .trailing)
                    Text("点击")
                        .frame(width: 42, alignment: .trailing)
                    Text("互动")
                        .frame(width: 42, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Constants.Colors.secondaryText)
                .padding(.horizontal, 4)

                Divider()

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.allAdsStats) { adInfo in
                        contentRow(adInfo)
                    }
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    @State private var expandedAdId: String?

    private func contentRow(_ adInfo: TopAdInfo) -> some View {
        let isExpanded = expandedAdId == adInfo.adId

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandedAdId = isExpanded ? nil : adInfo.adId
                }
            } label: {
                HStack(spacing: 0) {
                    aidCapsule(adInfo.adId)
                        .frame(width: 80, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(adInfo.adTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(adInfo.adSponsor)
                            .font(.system(size: 11))
                            .foregroundColor(Constants.Colors.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    let imp = adInfo.breakdown[.impression] ?? 0
                    let click = adInfo.breakdown[.click] ?? 0
                    let interactions = adInfo.breakdown[.like, default: 0] + adInfo.breakdown[.collect, default: 0] + adInfo.breakdown[.share, default: 0]

                    Text("\(imp)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 42, alignment: .trailing)
                    Text("\(click)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 42, alignment: .trailing)
                    Text("\(interactions)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 42, alignment: .trailing)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    Divider()
                    HStack(spacing: 16) {
                        expandedMetric("曝光", adInfo.breakdown[.impression] ?? 0, .blue)
                        expandedMetric("点击", adInfo.breakdown[.click] ?? 0, .green)
                        expandedMetric("CTR", ctrFor(adInfo), .orange)
                        expandedMetric("点赞", adInfo.breakdown[.like] ?? 0, .pink)
                        expandedMetric("收藏", adInfo.breakdown[.collect] ?? 0, .purple)
                        expandedMetric("分享", adInfo.breakdown[.share] ?? 0, .indigo)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }

            Divider().opacity(0.5)
        }
    }

    private func ctrFor(_ adInfo: TopAdInfo) -> String {
        let imp = adInfo.breakdown[.impression] ?? 0
        let click = adInfo.breakdown[.click] ?? 0
        guard imp > 0 else { return "-" }
        return String(format: "%.1f%%", Double(click) / Double(imp) * 100)
    }

    private func expandedMetric(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Constants.Colors.secondaryText)
        }
    }

    private func expandedMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Constants.Colors.secondaryText)
        }
    }

    private func miniMetric(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Constants.Colors.secondaryText)
            Text("\(value)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
    }

    // MARK: - Events Tab

    private var eventsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.stateChanges.isEmpty {
                stateChangeSection
            }
            recentEventsSection
        }
    }

    private var stateChangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("状态变更日志", icon: "clock.arrow.2.circlepath")

            ForEach(viewModel.stateChanges.prefix(20)) { event in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 10))
                        .foregroundColor(.teal)
                        .frame(width: 18)

                    aidCapsule(event.adId ?? "")

                    VStack(alignment: .leading, spacing: 3) {
                        if let sc = event.stateChange {
                            HStack(spacing: 4) {
                                Text(event.adTitle ?? event.adId ?? "")
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(stateChangeSummary(sc))
                                    .font(.system(size: 12))
                                    .foregroundColor(Constants.Colors.secondaryText)
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

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("最近事件", icon: "list.bullet.rectangle")

            ForEach(viewModel.enrichedEvents.prefix(30)) { event in
                HStack(spacing: 8) {
                    Image(systemName: iconForEvent(event.type))
                        .font(.system(size: 11))
                        .foregroundColor(colorForEvent(event.type))
                        .frame(width: 18)

                    if let adId = event.adId, !adId.isEmpty {
                        aidCapsule(adId)
                    }

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

    private func aidCapsule(_ aid: String) -> some View {
        Text(truncatedAID(aid))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.gray.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func truncatedAID(_ aid: String) -> String {
        if aid.count <= 16 { return aid }
        let prefix = String(aid.prefix(8))
        let suffix = String(aid.suffix(6))
        return "\(prefix)…\(suffix)"
    }

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
