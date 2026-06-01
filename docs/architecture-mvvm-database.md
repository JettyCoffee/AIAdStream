# AIAdStream MVVM 架构选型与数据库 Schema 设计

## 一、项目概览

AIAdStream 是一款 iOS 单列广告信息流 App，370 行 Swift 源码（不含种子脚本），采用 **SwiftUI + MVVM + SQLite** 技术栈，集成 **DeepSeek API** 提供 AI 驱动的对话式广告搜索。

| 维度 | 选型 |
|---|---|
| 语言 | Swift 6（Upcoming Features 全量开启） |
| UI 框架 | SwiftUI（iOS 26.2+） |
| 架构模式 | MVVM + @MainActor ObservableObject |
| 数据持久化 | SQLite3 C API（WAL 模式 + 串行队列） |
| AI 集成 | DeepSeek Chat API（SSE 流式 + Function Calling） |
| 视频播放 | AVPlayer 对象池复用（NSLock 线程安全） |
| 图片加载 | NSCache 内存缓存 + URLSession 异步下载 |
| 项目结构 | PBXFileSystemSynchronizedRootGroup（Xcode 16+ 自动文件同步） |

---

## 二、MVVM 分层架构

### 2.1 目录结构与职责

```
AIAdStream/
├── AIAdStreamApp.swift          # @main 入口，注入 FeedViewModel 为全局 @EnvironmentObject
├── ContentView.swift            # TabView 四栏根容器
│
├── Models/                      # 纯数据结构，无业务逻辑
│   ├── AdItem.swift             # 广告核心模型
│   ├── AdCardType.swift         # 卡片类型枚举（bigImage / smallImage / video）
│   ├── Channel.swift            # 频道枚举（featured / ecommerce / local）
│   ├── AITag.swift              # AI 标签模型 + TagCategory 枚举
│   ├── InteractionState.swift   # 互动状态（点赞/收藏/分享计数）
│   └── ChatMessage.swift        # AI 对话模型（ChatMessage / ToolCall / ToolDef /
│                                #   JSONSchema / StreamEvent / ConversationItem /
│                                #   ConversationRecord / PersistedItem）
│
├── Services/                    # 无 UI 依赖的纯业务/数据层
│   ├── DatabaseManager.swift    # SQLite3 封装（单例 + 串行队列）
│   ├── AdDataService.swift      # 广告分页/搜索/标签查询的门面
│   ├── DeepSeekService.swift    # DeepSeek API HTTP 客户端（SSE 流式消费）
│   ├── AIService.swift          # AI 对话编排层（system prompt + 工具调用循环）
│   ├── AnalyticsService.swift   # 埋点采集 + 聚合统计
│   └── VideoPlayerPool.swift    # AVPlayer 对象池（NSLock 线程安全）
│
├── ViewModels/                  # @MainActor + ObservableObject + @Published
│   ├── FeedViewModel.swift      # 信息流状态（频道切换/分页/标签筛选/互动）
│   ├── SearchViewModel.swift    # AI 搜索对话（流式消息/广告卡片/历史持久化）
│   ├── DetailViewModel.swift    # 详情页（标签缓存 + 广告上下文 AI 对话）
│   ├── AnalyticsViewModel.swift # 数据分析面板（聚合统计/排行榜）
│   └── SettingsViewModel.swift  # 设置页（@AppStorage API Key 管理）
│
├── Views/
│   ├── Feed/                    # 信息流：FeedView / AdCardView / 三种卡片
│   ├── Search/                  # AI 搜索：SearchView / ConversationHistoryView
│   ├── Detail/                  # 详情页：AdDetailView
│   ├── Analytics/               # 数据分析：AnalyticsDashboardView
│   ├── Settings/                # 设置：SettingsView
│   └── Common/                  # 可复用组件（ChannelTabBar / InteractionBar /
│                                #   LazyImageView / TagChipView / LoadingFooterView）
│
└── Utils/
    ├── Constants.swift          # 全局常量 + DeepSeek 配置 + 工具定义
    ├── ImageCache.swift         # 图片内存缓存
    └── DataPersistence.swift    # 数据持久化工具
```

### 2.2 层间通信规则

```
┌──────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                      │
│  - 只声明 UI 结构，不含业务逻辑                          │
│  - 通过 @StateObject / @EnvironmentObject 持有 VM       │
│  - 用户交互通过 VM 方法转发                              │
└──────────┬────────────────────────────┬───────────────┘
           │ @Published 驱动重绘          │
           │ VM 方法调用                  │
┌──────────▼────────────────────────────▼───────────────┐
│  ViewModels (@MainActor)                               │
│  - 持有 Service 引用，编排业务流程                        │
│  - @Published 属性暴露 UI 状态                           │
│  - 不直接操作 UI 组件                                    │
└──────────┬─────────────────────────────────────────────┘
           │ 同步/异步调用
┌──────────▼─────────────────────────────────────────────┐
│  Services                                              │
│  - DatabaseManager: 串行队列同步 SQLite 操作             │
│  - DeepSeekService: URLSession 异步 HTTP 流            │
│  - AnalyticsService: 埋点写入（不阻塞 UI）               │
│  - VideoPlayerPool: NSLock 线程安全池                   │
└────────────────────────────────────────────────────────┘
```

### 2.3 核心设计决策

#### 2.3.1 @MainActor + ObservableObject 模式

每个 ViewModel 标注 `@MainActor`，确保所有 `@Published` 属性变更发生在主线程。Swift 6 编译器通过 `-enable-upcoming-feature InferSendableFromCaptures` 等 flag 在编译期检查数据竞争。

```swift
@MainActor
final class FeedViewModel: ObservableObject {
    @Published var ads: [AdItem] = []
    // ...
}
```

#### 2.3.2 全局状态共享：@EnvironmentObject

`FeedViewModel` 在 `AIAdStreamApp` 入口注入为 `.environmentObject()`，所有子视图（FeedView、SearchView、AdDetailView）通过 `@EnvironmentObject` 读取同一实例，实现互动状态（点赞/收藏）的跨 Tab 同步。

```swift
// AIAdStreamApp.swift
Content()
    .environmentObject(feedViewModel)

// 任意子视图
@EnvironmentObject var feedViewModel: FeedViewModel
```

#### 2.3.3 页面级独立 ViewModel

SearchViewModel、DetailViewModel、AnalyticsViewModel、SettingsViewModel 各自使用 `@StateObject` 持有独立实例，生命周期与所在 View 绑定，页面销毁时自动释放。

#### 2.3.4 流式 AI 响应的状态管理

SearchViewModel 通过 `AsyncThrowingStream<StreamEvent, Error>` 消费 AIService 的流式输出：

```
StreamEvent 四阶段:
  contentDelta(delta)   → 增量文本追加到 streamingContent（打字机效果）
  toolCallStart(name)   → 显示"正在搜索..."状态提示
  toolCallResult(ads)   → 捕获结构化广告数据（暂存 pendingAds）
  done(fullContent)     → 追加 items: adCards + assistant message
```

关键设计点：
- 流式文本不直接追加到 messages 数组，而是写入独立的 `streamingContent` 字符串，避免 ForEach 频繁 diff 导致闪烁
- 广告卡片通过 `ConversationItem.adCards` 嵌入 items 有序列表，保证卡片紧跟其对应的 assistant 消息
- `streamTask` 在发送新消息或清空对话时 cancel，防止旧流污染新状态

#### 2.3.5 Tool Calling 循环

AIService 内部实现最多 5 轮 tool calling 循环：

```
User: "适合学生党的运动鞋"
  → LLM 调用 search_ads(query="运动鞋 学生")  ← 第 1 轮
  → App 执行 SQLite LIKE 查询，返回 JSON
  → LLM 生成总结文本 "这几款透气性好，性价比高"
  → StreamEvent.done
```

工具执行结果通过两种格式返回：
- **给 LLM**：JSON 文本（嵌入 ChatMessage role=tool）
- **给 UI**：结构化 `ToolResult(ads: [AdItem], detailAd: AdItem?)`

### 2.4 各 ViewModel 状态对照表

| ViewModel | @Published 状态 | 依赖 Service | 生命周期 |
|---|---|---|---|
| FeedViewModel | ads, currentChannel, isLoading, hasMore, interactionStates, activeTagFilter | AdDataService, AnalyticsService, DatabaseManager | App 全局（@EnvironmentObject） |
| SearchViewModel | inputText, items, isStreaming, streamingContent, errorMessage, showHistory | AIService, AnalyticsService, DatabaseManager | SearchView @StateObject |
| DetailViewModel | chatMessages, chatInput, isChatStreaming, chatStreamingContent, chatRecommendedAds, chatErrorMessage, tags | AIService, DatabaseManager | AdDetailView @StateObject |
| AnalyticsViewModel | selectedTab, events, channelStats, topAds | AnalyticsService | AnalyticsDashboardView @StateObject |
| SettingsViewModel | apiKey (@AppStorage) | UserDefaults | SettingsView @StateObject |

---

## 三、数据库 Schema 设计

### 3.1 概述

- **引擎**：SQLite3 C API（非 ORM，直接调用 C 函数）
- **文件位置**：`Documents/aiadstream.sqlite`
- **并发策略**：专用串行队列 `DispatchQueue(label: "com.aiadstream.db", qos: .userInitiated)`，所有 DB 操作通过 `dbQueue.sync {}` 同步执行
- **日志模式**：WAL（Write-Ahead Logging），支持并发读
- **外键**：`PRAGMA foreign_keys=ON`
- **种子策略**：首次启动从 Bundle 中的 `seed_ads.sqlite` 导入，版本号递增触发自动重播种

### 3.2 四张核心表

#### 3.2.1 ad_items —— 广告主表

```sql
CREATE TABLE IF NOT EXISTS ad_items (
    id          TEXT PRIMARY KEY,        -- UUID，如 "ad_001"
    title       TEXT NOT NULL,           -- 广告标题，≤30 字
    description TEXT NOT NULL,           -- 品牌/产品介绍，≥200 字
    image_url   TEXT NOT NULL,           -- Pexels 图片 URL
    video_url   TEXT,                    -- 视频 URL（仅 video 类型非空）
    card_type   TEXT NOT NULL,           -- bigImage | smallImage | video
    channel     TEXT NOT NULL,           -- featured | ecommerce | local
    sponsor     TEXT NOT NULL,           -- 品牌商名称
    ai_summary  TEXT NOT NULL            -- AI 生成的摘要（50-80 字）
);
```

**设计要点：**
- `video_url` 可为 NULL：bigImage / smallImage 类型无视频
- 无 `cta_text`、`ctr`、`budget` 等广告投放指标列 — 本项目定位为内容浏览而非广告投放平台，精简为核心展示字段
- 主键使用有意义的 ID（如 `ad_001`）而非自增整数，便于 LLM tool call 中引用

#### 3.2.2 ad_tags —— AI 标签表

```sql
CREATE TABLE IF NOT EXISTS ad_tags (
    id       TEXT PRIMARY KEY,                              -- UUID
    ad_id    TEXT NOT NULL,                                 -- 外键 → ad_items.id
    name     TEXT NOT NULL,                                 -- 标签名，≤3 字
    category TEXT NOT NULL,                                 -- category | style | audience
    FOREIGN KEY (ad_id) REFERENCES ad_items(id) ON DELETE CASCADE
);
```

**设计要点：**
- 每个广告 3 个标签（品类、风格、受众各 1 个）
- 外键级联删除：删除广告时自动清理标签
- 标签名 ≤3 字（如"运动鞋""简约""学生党"），便于标签栏紧凑展示
- 三分类枚举（category/style/audience）替代旧版的四分类（移除了 scene）

#### 3.2.3 interaction_states —— 互动状态表

```sql
CREATE TABLE IF NOT EXISTS interaction_states (
    ad_id        TEXT PRIMARY KEY,                          -- 外键 → ad_items.id
    is_liked     INTEGER NOT NULL DEFAULT 0,                -- 0/1 布尔
    is_collected INTEGER NOT NULL DEFAULT 0,                -- 0/1 布尔
    like_count   INTEGER NOT NULL DEFAULT 0,                -- 点赞总数
    share_count  INTEGER NOT NULL DEFAULT 0,                -- 分享总数
    FOREIGN KEY (ad_id) REFERENCES ad_items(id) ON DELETE CASCADE
);
```

**设计要点：**
- `ad_id` 作为主键：每个广告只有一条互动记录（一对一关系）
- SQLite 无原生 BOOLEAN，用 INTEGER 0/1 存储；Swift 层通过 `(row["is_liked"] as? Int64 ?? 0) != 0` 转换
- 写入使用 `INSERT OR REPLACE`（UPSERT 语义）

#### 3.2.4 analytics_events —— 埋点事件表

```sql
CREATE TABLE IF NOT EXISTS analytics_events (
    id        TEXT PRIMARY KEY,        -- UUID
    event_type TEXT NOT NULL,          -- impression | click | like | collect | share | search | tagClick | stateChange
    ad_id     TEXT,                    -- 关联广告（非广告事件可为 NULL）
    channel   TEXT,                    -- 频道
    timestamp REAL NOT NULL,           -- Unix 时间戳（Double）
    metadata  TEXT                     -- JSON 字符串（AdContext / StateChangeInfo）
);
```

**设计要点：**
- 无外键约束：`ad_id` 可为 NULL（如 search 事件与具体广告无关）
- `timestamp` 使用 `REAL`（Double）而非 `INTEGER`，与 Swift `Date.timeIntervalSince1970` 直接映射
- `metadata` 存储 JSON 字符串，内含 `AdContext`（adTitle/adSponsor/cardType）或 `StateChangeInfo`（field/from/to），由 AnalyticsService 在读取时动态解析

### 3.3 查询模式

#### 分页查询（FeedView）

```sql
-- 基础分页
SELECT * FROM ad_items WHERE channel = ? ORDER BY id LIMIT ? OFFSET ?

-- 标签筛选分页（JOIN + DISTINCT）
SELECT DISTINCT a.* FROM ad_items a
JOIN ad_tags t ON a.id = t.ad_id
WHERE a.channel = ? AND t.name = ?
ORDER BY a.id LIMIT ? OFFSET ?
```

#### 全文搜索（LLM Tool Call: search_ads）

```sql
SELECT DISTINCT a.* FROM ad_items a
LEFT JOIN ad_tags t ON a.id = t.ad_id
WHERE (a.title LIKE ? OR a.description LIKE ? OR a.sponsor LIKE ? OR t.name LIKE ?)
-- 可选频道筛选
-- AND a.channel = ?
ORDER BY a.id DESC LIMIT 20
```

模糊匹配模式：`%keyword%`，同时搜索标题、正文、品牌名、标签名。

#### 多标签检索（LLM Tool Call: get_similar_ads）

```sql
SELECT a.*, COUNT(DISTINCT t.name) AS match_count
FROM ad_items a
JOIN ad_tags t ON a.id = t.ad_id
WHERE t.name IN (?, ?, ?)          -- 动态 IN 子句（占位符生成）
GROUP BY a.id
ORDER BY match_count DESC
LIMIT ?
```

动态 `IN` 占位符使用 `tags.map { _ in "?" }.joined(separator: ",")` 模式生成，防止 SQL 注入。

#### 标签聚合查询（频道筛选栏）

```sql
-- 某频道所有去重标签名
SELECT DISTINCT t.name FROM ad_tags t
JOIN ad_items a ON t.ad_id = a.id
WHERE a.channel = ?

-- 某频道标签 + 分类
SELECT DISTINCT t.name, t.category FROM ad_tags t
JOIN ad_items a ON t.ad_id = a.id
WHERE a.channel = ?
```

### 3.4 种子数据库结构

`seed_ads.sqlite` 与运行时数据库结构完全一致（`ad_items` + `ad_tags`），由 Python 脚本通过 DeepSeek LLM 批量生成 450 条中文广告数据：

| 频道 | 大图 | 小图 | 视频 | 合计 |
|---|---|---|---|---|
| featured（精选） | 50 | 50 | 50 | 150 |
| ecommerce（电商） | 50 | 50 | 50 | 150 |
| local（本地） | 50 | 50 | 50 | 150 |
| **合计** | **150** | **150** | **150** | **450** |

种子版本号通过 `UserDefaults.com.aiadstream.seed_version` 管理，递增触发全量重导入（`DELETE FROM ad_tags; DELETE FROM ad_items;` → `BEGIN TRANSACTION` → 逐行 INSERT → `COMMIT`）。

### 3.5 底层 SQLite3 封装模式

```swift
final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.aiadstream.db", qos: .userInitiated)

    // 查询辅助方法
    private func executeQuery(_ sql: String, bind: ((OpaquePointer) -> Void)?) -> [[String: Any]]
    private func executeScalar(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) -> Int64
    private func executeUpdate(_ sql: String, bind: (OpaquePointer) -> Void)

    // 行映射
    private func rowToAdItem(_ row: [String: Any]) -> AdItem
}
```

三条辅助方法覆盖所有 CRUD 场景，`rowToAdItem` 将 `[String: Any]` 字典映射为 Swift struct。

---

## 四、关键数据流

### 4.1 信息流浏览

```
FeedView 出现
  → FeedViewModel.loadInitialData()
    → DatabaseManager.loadAllInteractionStates()  ← 恢复互动状态
    → switchChannel(to: .featured)
      → AdDataService.fetchAds() → DatabaseManager.fetchAds() (SQLite)
      → ads = page.ads → @Published 触发 UI 重绘
```

### 4.2 AI 对话搜索

```
用户在 SearchView 输入 "适合学生党的运动鞋"
  → SearchViewModel.sendMessage()
    → items.append(.message(user))
    → AIService.chat(history: chatHistory)
      → DeepSeekService.streamChat() — HTTP POST + SSE
        → LLM: tool_calls[0] { name: "search_ads", args: {query: "运动鞋 学生"} }
      → AIService 执行 search_ads → DatabaseManager.searchAds() — SQLite LIKE
      → LLM: "这几款透气性和性价比都不错"
      → StreamEvent.done("这几款透气性和性价比都不错")
    → items.append(.adCards(resultAds))
    → items.append(.message(assistant))
    → persistConversation() → UserDefaults JSON
```

### 4.3 详情页 AI 对话

```
AdDetailView 出现（ad: AdItem）
  → DetailViewModel 初始化（含当前广告完整上下文）
  → 用户在底部输入 "这款适合跑步吗？"
    → DetailViewModel.sendChatMessage()
      → AIService.chatAboutAd(ad)  ← system prompt 包含当前广告 title/desc/tags
        → LLM 可调用 get_ad_detail(ad_id) 获取补充信息
        → LLM 可调用 get_similar_ads(ad_id) 推荐同类
      → chatMessages + chatRecommendedAds 更新
```

### 4.4 互动埋点

```
InteractionBar 按钮点击
  → FeedViewModel.toggleLike(for: adId)
    → interactionStates[adId] 更新
    → DatabaseManager.saveInteractionState()  ← SQLite INSERT OR REPLACE
    → AnalyticsService.trackWithAdContext(.like)  ← 写入 analytics_events 表
    → AnalyticsService.trackStateChange()  ← 状态变更审计日志
```

---

## 五、与 CLAUDE.md 规范对照

| CLAUDE.md 规范 | 实现位置 |
|---|---|
| MVVM + @MainActor + ObservableObject + @Published | 所有 ViewModel |
| 显式 `import Combine` | 所有使用 @Published 的 ViewModel |
| LazyVStack + ScrollViewReader.scrollTo 保留滚动位置 | FeedView |
| 卡片 12pt 圆角 / 16pt 内边距 / 12pt 间距 | AdCardView / 子卡片 |
| spring 动画 (response: 0.3, dampingFraction: 0.5) | InteractionBar |
| 禁止卡片 body 层 onTapGesture | AdCardView（使用 highPriorityGesture） |
| 数据库 IN 占位符生成模式 | DatabaseManager.fetchAdsByTags() |
| 筛选操作保留旧数据 + 顶部加载指示器 | FeedViewModel.isFiltering |
| 视频播放池：Constants.videoPlayerPoolSize = 3 | VideoPlayerPool |
