# 卡片动态化方案

## 问题

广告信息流需要支持三种卡片样式（大图、小图、视频），每种样式在布局、交互和资源占用上有本质差异。需要设计一套方案，在保证渲染性能的同时，让三种卡片的代码复用度尽可能高，新增一种卡片类型时改动最小。

## 方案对比

### 方案 A：单 CardView + 条件渲染

把所有样式写在一个 `AdCardView` 里，用 `if/switch` 控制不同区域的显隐。

```swift
// 伪代码
if ad.cardType == .bigImage {
    BigImageSection()
} else if ad.cardType == .smallImage {
    SmallImageSection()
} else {
    VideoSection()
}
```

**优点**：简单直接，一个文件搞定。

**缺点**：body 越长越难维护。三种卡片的布局差异很大——大图是图在上文在下，小图是左图右文，视频有播放器覆盖层。全堆在一个 View 里，每次修改都要在条件分支中找对应的代码段，出 bug 的概率随时间线性增长。

### 方案 B：策略模式 + 独立组件（选用）

用一个工厂方法 `AdCardView` 根据 `cardType` 分发到三个独立组件：`BigImageCard`、`SmallImageCard`、`VideoCard`。共享的 UI 元素（标签行、摘要区、互动栏、趣味解读横幅）抽取为 `CardComponents.swift` 中的可复用子组件。

```
AdCardView（分发层）
├── BigImageCard
│   └── 引用 CardTagRow, CardAISummary, InteractionBar, EnhanceBanner
├── SmallImageCard
│   └── 引用 CardTagRow, CardAISummary, InteractionBar, EnhanceBanner
└── VideoCard
    └── 引用 CardVideoOverlay, CardTagRow, CardAISummary, InteractionBar, EnhanceBanner
```

**优点**：每种卡片独立演进，互不影响。公共组件一处修改三处生效。新增卡片类型只需加一个文件和在 `AdCardView` 的 switch 里加一个 case。

**缺点**：需要多写几个文件。但这个"缺点"是纸面上的——把 300 行拆成 3 个 100 行的文件反而更好维护。

## 最终方案：共享组件库 + 独立卡片

### 卡片分发

`AdCardView` 只做一件事：根据 `ad.cardType` 分发到对应组件：

```swift
struct AdCardView: View {
    var body: some View {
        Group {
            switch ad.cardType {
            case .bigImage:  BigImageCard(...)
            case .smallImage: SmallImageCard(...)
            case .video:     VideoCard(...)
            }
        }
    }
}
```

所有卡片接收相同的参数签名——`ad`、`interactionState` binding、`onLike/onCollect/onShare` 回调、`onTagTap` 回调——确保 FeedView 调用侧不需要关心卡片类型。

### 共享子组件（CardComponents.swift）

| 组件 | 用途 | 复用情况 |
|------|------|----------|
| `CardTagRow` | 水平滚动的标签行，支持高亮选中标签 | 三种卡片 + 详情页 |
| `CardAISummary` | AI 摘要展示（紫色渐变背景 + sparkle 图标） | 三种卡片 |
| `InteractionBar` | 点赞/收藏/分享按钮行 | 三种卡片 + 详情页 |
| `EnhanceBanner` | AI 趣味解读结果横幅，打字机动画 | 三种卡片 |
| `EnhanceButton` | 触发趣味解读的按钮 | 三种卡片 |
| `CardSponsorLabel` / `CardTitleLabel` | 赞助商和标题文本样式 | 三种卡片 |
| `CardVideoOverlay` | 视频播放/暂停/静音控制层 | VideoCard + 详情页视频区 |

### cardStyle 修饰器

```swift
extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .padding(.horizontal, 16)
    }
}
```

统一所有卡片的圆角（12pt）、水平内边距（16pt）和阴影。卡片间距（12pt）通过 `LazyVStack(spacing: Constants.cardSpacing)` 控制。

## 列表滚动性能

### LazyVStack + ForEach + Identifiable

用 `LazyVStack` 包裹 `ForEach`，SwiftUI 自动处理 View 的按需创建和回收。Key 点：

- `AdItem` 实现 `Hashable`，`ForEach` 能精确识别哪些 item 需要重新渲染
- 分页加载（每页 10 条），避免一次创建大量 View
- 图片用 `LazyImageView` 异步加载 + `NSCache` 缓存，不在主线程解码

### 滚动位置恢复

用户从信息流点进详情页再返回，滚动位置应该停在刚才看的那条广告上。做法：

```swift
// 进入详情前记录位置
savedScrollAdId = ad.id
selectedAd = ad

// 返回后恢复
.onChange(of: selectedAd) { _, newValue in
    if newValue == nil, let target = savedScrollAdId {
        viewModel.suppressLoadMoreBriefly()  // 禁止返回瞬间的 loadMore 误触发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            proxy.scrollTo(target)  // ScrollViewReader.scrollTo
        }
    }
}
```

延迟 0.15 秒是实践出来的经验值：NavigationStack 的返回动画需要时间，立刻 `scrollTo` 会被动画覆盖掉。更短的延迟（0.05）偶尔失效，更长（0.3）用户能感知到跳动。

### 防止返回后列表被重排

FeedViewModel 里有两个相关机制：

1. `suppressLoadMoreBriefly()` 设置 1 秒的时间窗口，期间 `loadMoreIfNeeded` 直接 return——避免 `onAppear` 在返回瞬间触发非预期的分页加载
2. `shuffleSeed` 在频道切换和刷新时随机生成，但进入详情再返回**不**重新生成种子——保证列表顺序不变

### 下拉刷新不闪白

刷新时不清空 `ads` 数组。旧数据保持可见，只设 `isRefreshing = true` 显示系统刷新指示器。新数据到达后替换 `ads`，UI 自动更新。

## 手势冲突

SwiftUI 里 `.onTapGesture` 会吞噬子视图的手势——当卡片外层包了 `onTapGesture` 做点击进详情时，卡片内的标签按钮、互动按钮全部失效。

解决方法：

1. **卡片点击**：FeedView 用 `Button(action: { selectedAd = ad })` + `.buttonStyle(.plain)` 包裹卡片，而不是 `onTapGesture`
2. **视频卡播放按钮**：用 `highPriorityGesture(TapGesture().onEnded { ... })` 作用于视频区域局部 ZStack，不影响信息区的按钮和 NavigationLink
3. **子按钮**：所有卡片内的互动按钮都用 `.buttonStyle(.plain)` 保持原生手势响应

## 卡片圆角白边问题

`.clipShape(RoundedRectangle)` 与外层 `.background` + 内层 `.clipped()` 叠在一起时，圆角边缘会出现像素级白边。解决方案是在图片裁剪层加 `.compositingGroup()` —— 它强制 SwiftUI 在该层级先合成离屏纹理，避免跨层渲染导致的边缘泄露。这是一个很少被文档化但实际很常见的 SwiftUI 渲染行为。
