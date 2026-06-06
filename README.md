# AIAdStream

单列广告信息流 iOS App，基于 SwiftUI + MVVM，集成 DeepSeek 大模型实现智能标签、摘要生成和对话式广告搜索。

完成了训练营课题的全部核心功能与可选功能，并在卡片动态化、播放器资源复用、AI 输出约束和曝光统计等方向做了额外的工程优化。

## 功能概览

**信息流浏览**

单列卡片流，支持大图、小图、视频三种卡片样式。顶部 Tab 切换精选/电商/本地频道，频道切换与下拉刷新均保留旧数据可见直到新数据到达。列表滚动位置在进入详情页返回后精确恢复。

**AI 增强**

每条广告附带大模型生成的摘要和智能标签（品类/风格/受众），标签支持点击筛选。卡片上的"趣味解读"按钮调用大模型对广告进行幽默段子、打油诗、微型故事或创意标语的改写，结果以打字机动画逐字展示。

**对话式搜索**

用自然语言描述你想看的广告，大模型通过 Function Calling 自动调用本地数据库搜索、联网搜索和相似广告查找，边搜边聊。搜索结果以可点击的广告卡片嵌入对话流中，对话历史自动持久化。

**详情页与互动**

点击卡片进入详情页，图文/视频自动适配布局，视频进入内流自动播放。点赞、收藏、分享状态在信息流和详情页之间同步，存储到本地 SQLite 数据库。

**数据分析仪表盘**

实时统计曝光、点击、CTR、互动率等 KPI，提供趋势图、渠道分布和广告排行。支持创建自定义广告投放，与种子广告混排在信息流中展示。

**视频播放器池**

基于 AVPlayer 的对象池，默认池大小 3，支持外流（暂停/静音）和内流（自动播放/有声）两种播放模式。离开可视区自动回收播放器资源。

## 技术文档

详细的技术方案、难点分析和实现细节见 [docs/technic/](./docs/technic/README.md)：

- [架构总览](./docs/technic/architecture.md)
- [卡片动态化方案](./docs/technic/card-system.md)
- [数据层设计](./docs/technic/data-layer.md)
- [AI 集成方案](./docs/technic/ai-integration.md)
- [视频播放器池](./docs/technic/video-player.md)
- [埋点统计方案](./docs/technic/analytics.md)

## 快速开始

### 环境

- Xcode 26+（Swift 6 语言模式）
- iOS 26.0+
- DeepSeek API Key（可选，未配置时 AI 功能降级）

### 构建

```bash
git clone https://github.com/JettyCoffee/AIAdStream.git
cd AIAdStream
open AIAdStream.xcodeproj
```

在 Xcode 中选择 iPhone 17 模拟器，⌘R 运行。

命令行构建：

```bash
xcodebuild -project AIAdStream.xcodeproj -scheme AIAdStream -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 配置 AI 功能

1. 前往 [DeepSeek 开放平台](https://platform.deepseek.com/) 获取 API Key
2. 打开 App → 设置 → API Key → 输入 Key
3. Key 通过 iOS Keychain 安全存储，不会写入 UserDefaults 或日志

不配置 API Key 时，信息流浏览、标签筛选、互动和数据统计等本地功能不受影响，仅 AI 搜索和趣味解读不可用。

## 项目结构

```
AIAdStream/
├── Models/              数据模型
│   ├── AdItem           广告核心模型（Identifiable + Codable + Hashable）
│   ├── AdCardType       卡片类型枚举（bigImage / smallImage / video）
│   ├── AITag            AI 生成标签（品类 / 风格 / 受众）
│   ├── Channel          频道枚举（featured / ecommerce / local）
│   ├── InteractionState 互动状态（点赞 / 收藏 / 分享）
│   └── ChatMessage      对话消息、工具调用、流事件模型
│
├── Services/            业务逻辑层
│   ├── DatabaseManager  基于 SQLite3 的本地数据库（种子导入、CRUD、索引查询）
│   ├── AdDataService    数据获取封装（分页、搜索、标签过滤）
│   ├── AIService        DeepSeek 编排层（流式对话、Function Calling 循环）
│   ├── DeepSeekService  DeepSeek API SSE 流式客户端
│   ├── VideoPlayerPool  AVPlayer 对象池（默认 3 个实例）
│   ├── AnalyticsService 埋点统计服务（事件记录 + 聚合查询）
│   └── KeychainService  iOS Keychain 安全存储
│
├── ViewModels/          ViewModel 层（@MainActor + ObservableObject）
│   ├── FeedViewModel    信息流状态管理（频道、分页、标签过滤、推荐排序）
│   ├── SearchViewModel  对话式搜索状态（流式输出、对话持久化）
│   ├── DetailViewModel  详情页状态（标签、AI 对话）
│   ├── AnalyticsViewModel  数据仪表盘状态（KPI 聚合、趋势、排行）
│   └── SettingsViewModel  设置状态（API Key 管理、偏好标签）
│
├── Views/               视图层
│   ├── Feed/            FeedView / AdCardView / BigImageCard / SmallImageCard / VideoCard
│   ├── Search/          SearchView / ConversationHistoryView
│   ├── Detail/          AdDetailView / AIMiniPlayer
│   ├── Analytics/       AnalyticsDashboardView
│   ├── Settings/        SettingsView
│   └── Common/          CardComponents / LazyImageView / InteractionBar / TagChipView 等
│
└── Utils/               工具类
    ├── Constants        全局常量 + DeepSeek API 配置 + System Prompt
    └── ImageCache       NSCache 图片缓存（countLimit=100, totalCostLimit=100MB）
```

## 模块职责

| 模块 | 职责 | 任务 |
|------|------|----------|
| Models | 数据结构定义，纯值类型 | Codable 支持本地持久化，Hashable 支持列表去重 |
| Services | 数据库、网络、缓存、池管理 | 全单例模式，无状态或线程安全设计 |
| ViewModels | 视图状态管理，UI 事件处理 | @MainActor 保证主线程发布，Combine 驱动 UI 更新 |
| Views | 纯视图渲染，无业务逻辑 | 组件拆分到 Common/，避免视图层持有业务状态 |

## 开发规范

几点最重要的约定（完整列表见 [CLAUDE.md](./CLAUDE.md)）：

- **所有 ViewModel 必须显式 `import Combine`**，Xcode 26 起 MemberImportVisibility 要求不再自动导入
- **卡片组件禁止在 body 层用 `onTapGesture`**，会吞噬 NavigationLink 和内部 Button 事件
- **筛选/刷新不清空旧数据**，保留旧列表可见 + 顶部加载指示器，数据到达后替换
- **卡片图片一律 `contentMode: .fill` + `.black` 背景**，禁止 `.fit` 导致留白
- **所有背景色用语义化系统颜色**，禁止硬编码 `.white` 或 RGB 值
- **API Key 存 iOS Keychain**，禁止 UserDefaults / @AppStorage
- **数据库动态 IN 查询用占位符生成**：``tags.map { _ in "?" }.joined(separator: ",")``
- **动画优先用 spring**：`response: 0.3, dampingFraction: 0.5`

## AI 声明

本项目使用 Claude Code + DeepSeek API 辅助编程，遵循以下原则：

**对 AI 输出的验证方式**

- 所有 Claude 生成的 Swift 代码均通过 Xcode 编译验证和模拟器运行测试
- DeepSeek 的广告摘要和标签基于预构建的种子数据库（SQLite），经过人工审核后导入，不依赖运行时 LLM 的随意输出
- System Prompt 中通过严格的回复规则约束 LLM 输出格式（禁止列表、禁止重复卡片信息、限制回复长度）
- Function Calling 的工具定义通过 JSON Schema 约束参数类型和必填项

**我做的优化**

- DeepSeek Function Calling 实现了完整的 Tool Call → Execute → Tool Result → Continue 循环（最多 5 轮），而非简单的一次性调用
- 添加了首轮安全兜底：LLM 未调用工具时自动执行 `search_ads` 确保有结果返回
- 添加了 Rate Limiter（最小间隔 2 秒）防止 API 滥用
- AI 趣味解读的结果在 ViewModel 层以 `[String: String]` 字典缓存，避免重复请求
- 种子数据库带版本号（`seedVersionKey`），支持升级时自动清空旧数据重新导入

## 演示视频

[演示视频](https://my.feishu.cn/file/WoQeblHvho8VmYxQ9ALc8C7lnrb?from=from_copylink)（3-8 分钟，展示信息流浏览 → 刷新加载 → 摘要/标签 → 详情互动 → 对话搜索）

## License

MIT
