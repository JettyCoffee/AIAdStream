# 数据层设计

## 总体策略

本地 SQLite 为主，无后端。种子数据以预构建的 `.sqlite` 文件打入 Bundle，首次启动导入到 Documents 目录。用户行为（互动状态、埋点事件、对话历史）持久化在同一数据库中。

选 SQLite 而不是 Core Data / SwiftData 的理由：Core Data 的并发模型在 Swift 6 下与 `@MainActor` 的交互很麻烦，SwiftData 还不够稳定（iOS 26 下编译偶发 crash）。SQLite3 C API 虽然啰嗦，但行为完全可控——出问题时你能知道哪条 SQL 慢了，而不是在 Core Data 的堆栈里猜。

## 数据库表结构

```
ad_items
├── id TEXT PRIMARY KEY
├── title TEXT
├── description TEXT
├── image_url TEXT
├── video_url TEXT (nullable)
├── card_type TEXT
├── channel TEXT
├── sponsor TEXT
├── ai_summary TEXT

ad_tags
├── id TEXT PRIMARY KEY
├── ad_id TEXT → ad_items.id (CASCADE)
├── name TEXT
├── category TEXT

interaction_states
├── ad_id TEXT PRIMARY KEY → ad_items.id (CASCADE)
├── is_liked INTEGER
├── is_collected INTEGER
├── like_count INTEGER
├── share_count INTEGER

analytics_events
├── id TEXT PRIMARY KEY
├── event_type TEXT
├── ad_id TEXT (nullable)
├── channel TEXT (nullable)
├── timestamp REAL
├── metadata TEXT (nullable)
```

四张表，关系简单：`ad_tags` 对 `ad_items` 多对一，`interaction_states` 对 `ad_items` 一对一。

## 种子数据导入

种子数据以 `seed_ads.sqlite` 文件放在 App Bundle 中。这个文件是在开发阶段用脚本预构建的，包含了 30+ 条广告和对应的 AI 标签。

导入流程（`DatabaseManager.seedIfNeeded()`）：

1. 检查 `ad_items` 表是否有数据
2. 无数据 → 执行完整导入
3. 有数据但种子版本号过低 → 删旧表、重建、重新导入
4. 版本号和内容匹配 → 跳过

版本号机制解决了一个实际问题：训练营期间广告数据改了三次，每次都需要清空旧数据重新导入。不放版本号的话，老用户永远看不到新增的广告。

```swift
private static let seedVersionKey = "com.aiadstream.seed_version"
private static let currentSeedVersion = 3
```

## 线程安全

`DatabaseManager` 用串行队列保证线程安全：

```swift
private let dbQueue = DispatchQueue(label: "com.aiadstream.db", qos: .userInitiated)
```

所有数据库操作通过 `dbQueue.sync` 执行。没有用 `async` 是因为 ViewModel 已经通过 `await` 将调用放到协作任务池中，不阻塞主线程即可，不需要数据库层再做异步化。

## 分页与筛选

### 标准分页

```swift
func fetchAds(channel: String, offset: Int, limit: Int, tagFilter: String?) -> AdPage
```

- `offset = (page - 1) * pageSize`，pageSize 固定 10
- 返回值包含 `ads` 数组和 `hasMore` 标记（total > offset + pageSize）
- ViewModel 层控制页码：`currentPage` 从 1 开始，`loadMore` 前递增

### 标签筛选

标签筛选不走数据库层分页。做法是加载当前频道的全部广告，客户端打乱排序后再过滤：

```swift
let allAds = dataService.allAds(for: currentChannel)
let shuffled = applyRecommendation(allAds)
ads = shuffled.filter { ad in ad.tags.contains { $0.name == filter } }
hasMore = false  // 客户端筛选后已全量加载
```

为什么不全量走数据库？因为 `applyRecommendation()` 依赖种子值打乱和用户偏好排序，这个逻辑在 SQL 里难以表达。代价是频道下广告很多时（目前 30 条）性能没问题，如果未来扩展到几百条需要回到数据库层做标签 JOIN + 排序。

### 动态 IN 查询

检索多标签相似广告时，标签数量不固定，用占位符生成：

```swift
let placeholders = tags.map { _ in "?" }.joined(separator: ",")
let sql = "SELECT a.*, COUNT(DISTINCT t.name) AS match_count FROM ... WHERE t.name IN (\(placeholders))"
```

这是 CLAUDE.md 里记录的规范——不能用字符串拼接构造 SQL，有注入风险。

## 跨页面状态同步

点赞、收藏、分享的状态在信息流卡片和详情页之间需要同步。做法：

1. `InteractionState` 存储在 `FeedViewModel.interactionStates: [String: InteractionState]` 字典中
2. 任何修改通过 `FeedViewModel.toggleLike/Collect/Share` 方法，方法内部调用 `db.saveInteractionState()` 持久化
3. 详情页通过 `@EnvironmentObject var feedViewModel` 拿到同一个 `FeedViewModel` 实例，读写同一个字典
4. 详情页的互动栏 Binding 直接桥接：

```swift
let interactionBinding = Binding(
    get: { feedViewModel.interactionState(for: ad.id) },
    set: { feedViewModel.interactionStates[ad.id] = $0 }
)
```

App 启动时从数据库加载全部互动状态，确保冷启动后的状态正确。

## 对话历史持久化

搜索对话以 `ConversationRecord` 结构存到 UserDefaults（JSON 编码，最多 20 条）。这里没用 SQLite 是因为对话历史是低频小数据——用户不会一天搜几十次——JSON 文件的方式更简单，读写都在主线程也没关系。

## 方案对比：数据库选型

| 方案 | 理由 | 不选的原因 |
|------|------|-----------|
| Core Data | Apple 官方推荐，有 NSFetchedResultsController | Swift 6 下与 @MainActor 的交互复杂，调试困难 |
| SwiftData | iOS 26 原生支持，@Model 宏简洁 | Beta 阶段，编译偶发 crash，不适合交付项目 |
| SQLite3 C API | 行为完全可控，无黑盒 | 需要手写 SQL 和绑定逻辑，代码量大 |
| Realm | 对象型数据库，API 友好 | 引入第三方依赖，课题要求尽可能原生方案 |

选 SQLite3 C API 的核心逻辑是"可控性"比"便利性"更重要。两周的开发周期里，花在调试 SQLite 的时间很少——因为所有 SQL 都是自己写的，出问题时看日志就知道问题在哪。Core Data 的 merge conflict 和 context 管理在这个时间窗口里是不必要的心智负担。
