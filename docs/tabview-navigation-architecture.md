# TabView 导航架构重构

## 背景
原始设计将所有功能集中于 FeedView 的 NavigationStack 中，搜索和分析通过 toolbar 按钮导航。用户需要在三个功能间频繁切换时，导航栈越来越深。

## 问题
1. **导航栈膨胀**: 从 Feed → Search → Detail → Back 形成深层嵌套
2. **状态隔离**: Analytics 页面独立创建 ViewModel，切换回来时状态丢失
3. **入口可见性**: 搜索和数据分析隐藏在 toolbar 图标中，用户发现率低

## 方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| 保持 NavigationStack + Sheet | 改动最小 | 搜索为模态，体验割裂 |
| TabView + 各自 NavigationStack | 平行入口，状态保持 | 需重构导航结构 |
| 自定义 TabBar + ZStack | UI 完全可控 | 需手动管理页面生命周期 |

## 最终方案
选用 **TabView + 各自 NavigationStack**，原因：
- iOS 原生 TabView 提供标准的底部导航体验
- 每个 Tab 独立 NavigationStack，互不干扰
- Tab 切换时自动保持各页面状态（SwiftUI 默认行为）
- FeedViewModel 通过 @EnvironmentObject 跨 Tab 共享，保证互动状态一致

## 设计要点
- ContentView 只包含 TabView，不嵌套额外导航层
- FeedView、SearchView、AnalyticsView 各自包裹 NavigationStack
- FeedViewModel 在 App 入口创建并注入，全生命周期共享
- Tab 切换不触发数据重新加载，仅在首次 appear 时加载
- AnalyticsDashboardView 每次 appear 时 refresh 以获取最新埋点数据
