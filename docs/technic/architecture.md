# 架构总览

## MVVM 分层

项目采用 SwiftUI + MVVM，是 iOS 信息流 App 最常见的选型。比起 MVC（ViewController 容易变成 God Object）和 MVVM-C（引入 Coordinator 增加复杂度但这个小项目用不上），MVVM 在 SwiftUI 的 `@Published` + `@StateObject` 机制下是最自然的。

```
┌──────────────────────────────────────────────┐
│  Views                                       │
│  FeedView / SearchView / DetailView / ...    │
│  @EnvironmentObject / @StateObject / @Binding│
└──────────────┬───────────────────────────────┘
               │ 用户事件 + 数据绑定
┌──────────────▼───────────────────────────────┐
│  ViewModels (@MainActor)                     │
│  FeedVM / SearchVM / DetailVM / AnalyticsVM  │
│  @Published 属性驱动 UI 更新                   │
└──────────────┬───────────────────────────────┘
               │ async/await
┌──────────────▼───────────────────────────────┐
│  Services (单例)                              │
│  DatabaseManager / AIService / DeepSeekService│
│  VideoPlayerPool / AnalyticsService          │
└──────────────┬───────────────────────────────┘
               │ SQLite3 C API / URLSession
┌──────────────▼───────────────────────────────┐
│  Models (纯值类型, Codable + Hashable)         │
│  AdItem / AITag / ChatMessage / ...          │
└──────────────────────────────────────────────┘
```

View 层只负责渲染和转发事件，不持有业务状态。ViewModel 层通过 `@MainActor` 保证所有 `@Published` 属性在主线程更新——这是 Swift 6 并发模型的硬性要求，不加编译器直接报错。

Service 层全部是单例，无状态或自带线程安全（DatabaseManager 用串行队列，VideoPlayerPool 用 NSLock）。

## 数据流向

以一次频道切换为例：

1. 用户点击 Tab → `ChannelTabBar` 通过 `$viewModel.currentChannel` 的 Binding 修改值
2. `FeedView.onChange(of: currentChannel)` 触发 `viewModel.switchChannel(to:)`
3. ViewModel 设 `isLoading = true`，清空旧列表，调用 `AdDataService.fetchAds(channel:page:)`
4. AdDataService 调用 `DatabaseManager.fetchAds(channel:offset:limit:)`
5. DatabaseManager 在 `dbQueue` 串行队列中执行 SQLite 查询
6. 结果返回到 ViewModel，`ads` 数组更新 → `@Published` 通知 View 重绘

关键点：`isLoading` 在步骤 3 立即设为 true，但旧数据在 `ads = []` 之后才清空——实际上我们有意识地保留了旧数据的可见性（见 `loadPage` 的实现，只在拿到新数据后才替换 `ads`）。

## 模块依赖

依赖方向从上到下，无循环：

- Models 不依赖任何模块
- Services 依赖 Models，数据库层直接读写 AdItem 等结构体
- ViewModels 依赖 Services 和 Models
- Views 依赖 ViewModels（通过 `@EnvironmentObject`、`@StateObject`、`@ObservedObject`）

全局常量放在 `Utils/Constants.swift`，是唯一被所有层级引用的模块。图片缓存和 Keychain 服务也在 Utils/ 目录下。

## Swift 6 并发适配

几个在实践中遇到并处理的问题：

1. **@MainActor 隔离**：所有 ViewModel 标注 `@MainActor`。但要注意函数默认参数不能引用 `@MainActor` 隔离的静态属性——需要在调用处显式传参，不能用 `= Constants.pageSize` 这种写法。

2. **Combine 显式导入**：Xcode 26 引入 `MemberImportVisibility`，使用 `@Published` 必须显式 `import Combine`，编译器不再自动桥接。

3. **NotificationCenter 回调**：FeedViewModel 监听 `userAdDidChange` 通知，回调闭包中需要用 `Task { [weak self] in await self?.refresh() }` 包装，确保回到 MainActor 上下文。

## 方案对比：为什么不用其他架构

| 方案 | 优点 | 不选的原因 |
|------|------|-----------|
| TCA (The Composable Architecture) | 状态管理严谨、可测试性强 | 学习曲线陡，小项目过度设计；Reducers 和 Store 的模板代码太多 |
| UIKit + MVC | 成熟稳定、第三方库丰富 | SwiftUI 是这个课题的未来方向；手动管理 UITableView 复用和自动布局成本高 |
| MVVM + FlowCoordinator | 页面路由清晰 | 项目页面就 4 个 Tab，NavigationStack 内置路由够用，不需要额外抽象 |

MVVM 在 SwiftUI 里的"样板代码"是最少的：`@Published` 声明状态，`ObservableObject` 自动通知 View 更新。对于一个 2 周开发周期的项目来说，开发效率比架构纯度重要。
