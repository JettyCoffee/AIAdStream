# 跨页面状态同步与动效反馈

## 背景
广告信息流中，用户可能在 Feed 列表、搜索结果、详情页三个页面中对同一条广告进行互动（点赞/收藏/分享），需要确保状态实时同步，并提供流畅的动效反馈。

## 问题
1. **状态一致性问题**: Feed 点赞后进入详情，详情应看到最新状态；详情收藏后返回 Feed，Feed 卡片应即时更新
2. **持久化时效**: 状态需在内存中立即生效，同时异步持久化到数据库
3. **动效流畅性**: 互动按钮需要即时视觉反馈，不能被持久化 I/O 阻塞

## 方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| 通知中心 (NotificationCenter) | 解耦，跨层级传递 | 难以追踪数据流，调试困难 |
| 每个页面独立状态 + 回传 | 页面自治 | 同步延迟，需手动管理回传 |
| @EnvironmentObject 共享 ViewModel | 单一数据源，自动同步 | ViewModel 需覆盖所有场景 |

## 最终方案
选用 **@EnvironmentObject 共享 FeedViewModel**，原因：
- 单一数据源（Single Source of Truth）：`interactionStates` 字典由 FeedViewModel 唯一持有
- SwiftUI 自动响应：@Published 属性变化时所有订阅视图自动刷新
- 持久化不阻塞 UI：状态先更新内存（即时动画），数据库写入由串行队列异步完成

## 设计要点
- `interactionStates: [String: InteractionState]` 以 adId 为键，确保同一条广告在任意页面引用同一份状态
- toggleLike/toggleCollect 先去重更新内存字典，再用 dbQueue 异步写 SQLite
- InteractionBar 使用 `.spring(response: 0.3, dampingFraction: 0.5)` 实现弹性动画
- Like 按钮额外叠加 `scaleEffect` 弹跳（1.0 → 1.5 → 1.0），提供点赞彩蛋体验
- Channel 切换和 Tag 筛选使用 `.easeInOut(duration: 0.2)` 过渡动画
