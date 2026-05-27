# @Binding 与 ViewModel 双重状态变更冲突

## 背景
AIAdStream 的互动状态（点赞/收藏/分享）以 `InteractionState` 结构体存储在 `FeedViewModel.interactionStates` 字典中，通过 SQLite 持久化。视图层通过 `@Binding` 读取状态，通过闭包回调（onLike/onCollect/onShare）通知 ViewModel 执行持久化和埋点。

## 问题
点赞/收藏/分享按钮点击后无实际效果。`isLiked` 属性在点击瞬间闪烁后恢复原值，`likeCount` 未发生变化，数据库中无记录。

### 根因分析

**InteractionBar** 的按钮 action 中同时做了两件事：

1. 通过 `@Binding` 直接修改 `InteractionState`：
```swift
state.isLiked.toggle()
state.likeCount += state.isLiked ? 1 : -1
```
这会触发 Binding 的 setter，写入 `FeedViewModel.interactionStates[adId]`。

2. 调用 `onLike?()`，触发 `FeedViewModel.toggleLike(for:)`：
```swift
func toggleLike(for adId: String) {
    var state = interactionState(for: adId)  // 读到已被 Binding 修改后的值
    state.isLiked.toggle()                    // 再次取反，回到原始值
    state.likeCount += state.isLiked ? 1 : -1 // 反向调整计数
    update(state, for: adId)                   // 覆盖写入
}
```

两个写入方按照相反的逻辑操作同一数据，执行轨迹：

| 步骤 | 操作方 | 动作 | isLiked | likeCount |
|------|--------|------|---------|-----------|
| 0 | - | 初始状态 | false | 0 |
| 1 | InteractionBar (Binding) | toggle isLiked | true | - |
| 2 | InteractionBar (Binding) | likeCount +1 | true | 1 |
| 3 | FeedViewModel | 读取 state | true | 1 |
| 4 | FeedViewModel | toggle isLiked | false | - |
| 5 | FeedViewModel | likeCount -1 | false | 0 |
| 6 | FeedViewModel | update() 覆盖写入 | false | 0 |

最终状态回到原点，用户无感知。

## 方案对比

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| A. View 纯消费，ViewModel 唯一写入 | InteractionBar 移除所有 `state.xxx =`，仅触发 `onLike?()` 回调 | 单一写入口，数据流清晰，无竞争 | 需要确保 ViewModel 回调后 SwiftUI 能正确刷新 Binding |
| B. ViewModel 不再写入，仅持久化 | InteractionBar 保留 Binding 写入，ViewModel 回调仅执行 `db.save()` + 埋点 | 减少一次状态读取 | View 层承担业务逻辑（count 增减规则），违反 MVVM 分层；多个使用 InteractionBar 的页面需各自复制写入逻辑 |
| C. 事件分发模式 | 引入 `InteractionAction` 枚举，Button 发送 Action 到 ViewModel 统一处理 | 可扩展性强，适合复杂交互 | 引入额外抽象层，对于当前 3 个按钮的简单场景过度设计 |

## 最终方案

选择 **方案 A**：InteractionBar 只读不写，FeedViewModel 为唯一状态写入方。

修改内容：
- `InteractionBar` 三个按钮的 action 闭包中移除 `state.isLiked.toggle()` / `state.likeCount +=` / `state.isCollected.toggle()` / `state.shareCount +=` 等直接写入操作
- 仅保留 `onLike?()` / `onCollect?()` / `onShare?()` 回调调用
- Like 按钮的 scale 弹跳动画改为在回调执行后读取 `state.isLiked`（此时 ViewModel 已完成写入，Binding getter 返回最新值）

## 设计要点
- **唯一写入方原则**：任何可变状态（尤其需要持久化的状态）只允许一个组件直接修改，其余组件通过回调/通知委托写入
- **@Binding 的安全边界**：`@Binding` 适用于父子 View 间的双向数据传递，但当写入操作还触发持久化、埋点等副作用时，应让回调闭包负责写入，View 仅消费显示
- **回调时序**：`onLike?()` 先执行 ViewModel 状态变更，再读取 `state.isLiked` 判断是否需要弹跳动画，确保读取的是变更后的值
- **跨页面一致性**：FeedView、SearchView、AdDetailView 三个页面共享同一个 `FeedViewModel` 和同一套回调，修复一次性覆盖所有互动入口
