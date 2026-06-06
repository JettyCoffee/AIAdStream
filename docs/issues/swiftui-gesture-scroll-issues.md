# SwiftUI 卡片手势冲突与滚动位置保留

## 背景

信息流中的广告卡片同时承载多种交互：NavigationLink 跳转详情、InteractionBar（点赞/收藏/分享按钮）、标签点击筛选、视频播放/暂停。这些交互在同一视图层级中需要正确的事件分发，否则会出现按钮无响应或手势互斥。

从详情页返回时，LazyVStack 的所有可见 cell 会重建，导致滚动位置丢失。

## 问题 1：VideoCard 的 onTapGesture 吞噬所有点击

### 现象
VideoCard body 层添加 `.onTapGesture` 用于播放/暂停后，NavigationLink 的详情跳转完全失效，InteractionBar 的点赞/收藏按钮也无法点击。

### 原因
SwiftUI 手势系统中，`.onTapGesture` 附加在视图 body 最外层时，会拦截该视图内所有区域的点击事件。即使该区域包含 `NavigationLink`（底层是 `Button`）和独立的 `Button` 控件，手势仍不会穿透到子视图。

### 方案对比

| 方案 | 描述 | 优缺点 |
|---|---|---|
| A. 仅用播放按钮 | 移除 `onTapGesture`，用户只能通过显式播放按钮控制 | 简单，但交互不直观；用户习惯点击视频区域播放 |
| B. `allowsHitTesting(false)` | 禁用卡片层的 hit testing | 导致 NavigationLink 也失效，不可行 |
| C. `highPriorityGesture` 局部应用 | 将播放手势仅附加到视频 ZStack 区域 | 视频区可点击播放，其他区域正常响应 NavigationLink 和 Button |

### 最终方案：方案 C - highPriorityGesture 局部作用

```swift
// 视频区 ZStack 上
.highPriorityGesture(
    TapGesture().onEnded {
        if !isPlaying {
            setupPlayer()
            player?.play()
            isPlaying = true
        }
    }
)
// 下方内容区（标题、标签、互动栏）不附加手势，事件正常冒泡
```

### 设计要点
- `highPriorityGesture` 的优先级高于子 Button，但 SwiftUI 对 `Button` 有特殊处理：Button 内部的 tap 不会被父层手势拦截
- 手势仅附加到 ZStack（视频区域），不污染整个卡片 body
- 播放/暂停按钮用独立的 `Button` 控件，天然优先级最高

---

## 问题 2：CardPressStyle 导致子 Button 点击失效

### 现象
自定义 `ButtonStyle`（缩放动画）应用在 `NavigationLink` 上后，SmallImageCard 内的 `InteractionBar` 按钮完全无响应。

### 原因
`NavigationLink` 底层是 `Button`，应用自定义 `ButtonStyle` 后：
- `ButtonStyle.makeBody(configuration:)` 中的 `scaleEffect` 改变视图的渲染帧
- 子 Button 在父 NavigationLink 被按下时发生位置偏移
- 点击事件的坐标在偏移后可能落在子 Button 的有效区域之外
- 即使 SwiftUI 的"最内层 Button 优先"规则仍然生效，但命中测试在动画帧之间已失效

### 方案对比

| 方案 | 描述 |
|---|---|
| A. 自定义 `ButtonStyle` 仅做 opacity 变化 | 不产生位移，但仍有轻微视觉反馈 |
| B. 用 `.highPriorityGesture` 替代 ButtonStyle | 在卡片上叠放手势做反馈，但会与 NavigationLink 冲突 |
| C. 移除自定义 ButtonStyle，使用 `.plain` | 无动画反馈，但所有子控件正常响应 |

### 最终方案：方案 C

```swift
NavigationLink { ... } label: { AdCardView(...) }
    .buttonStyle(.plain)           // 不自定义
    .contentShape(Rectangle())     // 确保整个区域可点击
```

### 设计要点
- iOS 原生 `NavigationLink` + `.plain` 已提供足够的视觉反馈（cell 选中高亮）
- 额外的动画反馈不如功能正确性重要
- 卡片间距和布局精度比按压动画更能提升体验

---

## 问题 3：LazyVStack 滚动位置在 NavigationStack pop 后丢失

### 现象
从详情页点击返回后，信息流滚动位置不固定，有时跳到顶部，有时跳到中间的不确定位置。

### 原因
- `NavigationStack` push/pop 时，根视图保持存活但 `LazyVStack` 的 cell 会重建
- 重建时 `onAppear` 对所有可见 cell 依次触发
- 如果在 `onAppear` 中持续更新 `lastVisibleAdId`，又在 `ScrollView.onAppear` 中 `scrollTo(lastVisibleAdId)`，两者竞争：
  1. ScrollView.onAppear → scrollTo(savedId)
  2. 滚动过程中 cell 的 onAppear 触发 → lastVisibleAdId 被更新
  3. 导致下一次 scrollTo 的目标与当前滚动动画冲突

### 方案对比

| 方案 | 描述 | 问题 |
|---|---|---|
| A. `ScrollViewReader.scrollTo` + 延迟 | 返回时延迟 0.5s 后 scrollTo | 延迟太短可能仍冲突，太长用户可见跳动 |
| B. `scrollPosition(id:)` (iOS 17+) | 使用原生 scrollPosition binding | 需要 iOS 17+，且 LazyVStack 后 cell 的 id 可能尚未就绪 |
| C. 一次性记录 + 一次性恢复 | 仅在导航离开时记录位置，返回时一次性 scrollTo，之后不再追踪 | 需要在 NavigationLink 点击时记录 |

### 最终方案：方案 C - simultaneousGesture 记录 + 一次性恢复

```swift
// 在 NavigationLink 上附加 gesture 记录点击时刻的位置
.simultaneousGesture(
    TapGesture().onEnded {
        savedScrollAdId = ad.id
        needsScrollRestore = true
    }
)

// 在 ScrollView.onAppear 中一次性恢复
.onAppear {
    guard needsScrollRestore, let target = savedScrollAdId else { return }
    needsScrollRestore = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        proxy.scrollTo(target, anchor: .top)
    }
}
```

### 设计要点
- `.simultaneousGesture` 不阻止 NavigationLink 的原有行为，仅同时记录信息
- `needsScrollRestore` 是一次性标志，恢复后不再追踪后续滚动
- 0.15s 延迟让 LazyVStack 的 cell 重建完成后再执行 scrollTo
- 切换频道时重置 `savedScrollAdId = nil`，避免跨频道错误恢复
