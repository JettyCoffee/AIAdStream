# 埋点统计方案

## 设计目标

课题要求支持模拟互动（点赞、收藏、分享）并展示曝光/点击等统计信息。数据全部本地模拟，不上报服务端。核心要做三件事：

1. **事件收集**：在用户行为发生点记录事件
2. **事件富化**：事件携带足够的上下文信息（广告标题、品牌、卡片类型等），方便后续聚合
3. **可视化展示**：以 Dashboard 形式展示 KPI、趋势图和排行

## 事件模型

```swift
enum AnalyticsEventType: String, Codable, CaseIterable {
    case impression   // 曝光
    case click        // 点击进详情
    case like         // 点赞
    case collect      // 收藏
    case share        // 分享
    case search       // AI 搜索
    case tagClick     // 标签点击
    case stateChange  // 状态变更（调试用）
}
```

每条事件记录携带：

| 字段 | 说明 |
|------|------|
| `id` | UUID，事件唯一标识 |
| `type` | 事件类型枚举 |
| `adId` | 关联广告 ID（搜索和状态变更事件可为空） |
| `channel` | 当前频道 |
| `timestamp` | 事件时间戳 |
| `metadata` | 富化上下文的 JSON，包含广告标题/品牌/卡片类型，状态变更事件还包含变更前后值 |

## 曝光统计口径

这是信息流广告最容易被质疑的点——"曝光"怎么定义。

### 口径选择

我们采用 **≥1 秒可视** 作为曝光标准。做法：

```swift
.onAppear {
    viewModel.trackImpression(adId: ad.id)
}
```

为什么是 `onAppear` 而非更精确的方案？对比：

| 方案 | 精度 | 复杂度 | 选择 |
|------|------|--------|------|
| `onAppear` 即计曝光 | 低，滚得快也计 | 零成本 | 当前方案 |
| `onAppear` + 停留 1 秒后才计 | 中，过滤快速划过 | 需要 Timer + 取消逻辑 | 下一迭代 |
| 可视区域比例 > 50% 才计 | 高 | 需要 GeometryReader + PreferenceKey | 过度设计 |

当前项目选择了方案一。理由：我们的广告卡片几乎占满屏幕宽度，单列信息流的"滚动经过"和"真正看到"之间的差异比双列瀑布流小很多。而且课题要求的是模拟统计——`onAppear` 就计曝光的偏差在演示中可以解释，不会影响答辩。

`Constants.impressionThreshold = 1.0` 这个常量已经预留了，以后改方案二只需要在 `onAppear` 里加一行 Timer。

### 去重

目前没有去重。同一张卡片滚出可视区再滚回来，`onAppear` 会再次触发。对于模拟数据来说这不是大问题——反而让曝光数据更好看——但生产环境下需要加上 `trackedImpressionAdIds: Set<String>` 做内存级去重。

## 事件富化

不是简单记"某用户点赞了"，而是记录点赞的目标广告是谁：

```swift
func trackWithAdContext(_ type: AnalyticsEventType, ad: AdItem, channel: Channel?, extra: String?) {
    let context = AdContext(adTitle: ad.title, adSponsor: ad.sponsor, cardType: ad.cardType.rawValue)
    // 编码为 JSON 存入 metadata
}
```

`AdContext` 里存了广告标题、品牌、卡片类型。这些信息在 Dashboard 展示时直接解析 metadata，不需要 JOIN 广告表——查询更快，而且删除广告后历史事件仍然可读。

## 事件存储

用 SQLite 的 `analytics_events` 表，不在内存中缓存。以下操作直接读数据库：

```swift
func impressionCount() -> Int { allEvents().filter { $0.type == .impression }.count }
```

这在小数据量下完全没问题（训练营期间几百条事件），但 `allEvents()` 每次都全表扫描。生产环境下需要加聚合查询（`SELECT COUNT(*) WHERE event_type = 'impression'`）或预计算物化视图。

## KPI 与可视化

### KPI

| 指标 | 计算方式 | 展示位置 |
|------|----------|----------|
| 曝光量 | impressionCount() | KPI 卡片 |
| 点击量 | clickCount() | KPI 卡片 |
| CTR | clickCount / impressionCount × 100 | KPI 卡片 |
| 互动量 | likeCount + collectCount + shareCount | KPI 卡片 |
| 互动率 | 互动量 / 曝光量 × 100 | KPI 卡片 |
| 分享数 | shareCount() | KPI 卡片 |

### Dashboard 布局

AnalyticsDashboardView 从上到下分为：

1. **创作者头像区**：用户身份 + 创建广告入口
2. **时间范围选择器**：Segmented Picker 切换 7 天 / 30 天
3. **KPI 网格**：2 列 Grid 展示 6 个核心指标卡片
4. **趋势图**：自定义 BarChart，按天聚合曝光和点击（`DailyTrendPoint`）
5. **渠道分布**：按频道拆分的曝光量和 CTR 对比
6. **广告排行 TOP5**：可展开查看事件细分（曝光/点击/CTR/点赞/收藏/分享）
7. **我的广告**：用户创建的广告列表，每条带迷你指标条

趋势图用纯 SwiftUI 绘制（`GeometryReader` + `RoundedRectangle`），没有依赖 Charts 框架——iOS 26 的 Charts 框架行为还不够稳定，Canvas 绘制在列表滚动时的复用有问题。

### 时间过滤

`AnalyticsViewModel` 维护 `selectedPeriod: TimePeriod`（7 天/30 天），`refresh()` 时过滤 `allEvents()` 中在时间窗口内的事件，重新聚合所有指标。

## 创建广告与混排

Dashboard 支持用户创建广告。创建时：

1. 收集标题、品牌、描述、频道、卡片类型、标签
2. 生成 UUID 作为 adId
3. 标签按逗号分隔，每个标签自动分配品类（目前固定为 `category`）
4. 通过 `DatabaseManager.insertAd()` 写入数据库
5. 发送 `Notification.Name.userAdDidChange` 通知
6. FeedViewModel 收到通知后自动刷新信息流

用户创建的广告和种子广告在信息流中混排，通过推荐排序算法（偏好标签匹配度）决定位置。创建时没有真实图片 URL，`LazyImageView` 检测到空 URL 时会显示占位色块而不是错误图标。
