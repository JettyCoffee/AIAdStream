# 详情页可拖动 AI 面板设计

## 背景

详情页的 AI 助手原本使用 `.sheet(isPresented:)` + `.presentationDetents([.medium, .large])` 实现。这是 iOS 16+ 的标准模态弹窗方案，但存在两个体验问题：

1. **打断浏览**：sheet 以模态动画弹出，完全覆盖底层内容，用户看不到广告详情
2. **交互割裂**：关闭 sheet 后才能操作互动按钮（点赞/收藏/分享），无法边看广告边问 AI

## 问题

需要将模态弹窗替换为内联可拖动面板，支持在详情页内部向上拖动拉出 AI 对话，不离开当前页面。

约束：
- 面板默认紧凑模式（约 72pt），显示互动栏 + AI 入口
- 支持拖动到中等（38% 屏幕）和完整（78% 屏幕）两个展开档位
- 展开时底层内容变暗但不消失
- 需适配 iOS 26 SwiftUI，避免使用已弃用的 `UIScreen.main`

## 方案对比

### 方案 A：使用 `.interactiveDismissDisabled` + 自定义 `.sheet` 修饰符

保持 `.sheet` 框架，通过 `presentationDetents` 增加 `.fraction(0.15)` 作为默认档位，`.interactiveDismissDisabled(true)` 禁止关闭。

```swift
.sheet(isPresented: $showSheet) {
    content
        .presentationDetents([.fraction(0.15), .medium, .large])
        .interactiveDismissDisabled(true)
}
```

**优点**：改动量极小，利用系统手势

**缺点**：
- `.fraction(0.15)` 不支持自定义背景和内容，依然会显示标准 sheet 的圆角和拖拽条
- `.interactiveDismissDisabled` 阻止了"点击外部关闭"的直觉行为
- sheet 仍然脱离原页面上下文，NavigationStack 内的返回手势可能冲突

### 方案 B：ZStack + 自定义 DragGesture 面板（采用）

自建 `DraggableAIPanel` 组件，放在详情页 `ZStack(alignment: .bottom)` 中，通过 `DragGesture` + `offset` 控制位置。

```swift
ZStack(alignment: .bottom) {
    ScrollView { /* 内容 */ }
    if panelState != .bar {
        Color.black.opacity(dimmingOpacity).ignoresSafeArea()
            .onTapGesture { panelState = .bar }
    }
    DraggableAIPanel(panelState: $panelState)
}
```

**优点**：
- 完全控制面板样式（圆角、背景材质、拖拽条）
- 遮罩层透明度随面板高度平滑变化
- 不脱离页面上下文，NavigationStack 手势不受影响
- 互动栏在 `.bar` 状态始终可见

**缺点**：
- 需要自行实现拖拽物理和吸附逻辑
- 代码量较大（~200 行）

## 最终方案

采用方案 B。核心设计要点：

1. **三态枚举**：`AIPanelState` 定义 `.bar(72pt)` / `.medium(38%)` / `.large(78%)`，高度通过 `GeometryReader` 获取屏幕尺寸（替代弃用的 `UIScreen.main`）

2. **拖拽物理**：
   - 拖动超过边界时施加 0.3 倍阻尼系数（`dragOffset = translation * 0.3`）
   - 松手时检测 velocity：> 300pt/s 快速滑入相邻档位
   - 慢速拖动用 40pt 阈值判断是否切换档位
   - 吸附动画使用 `.interpolatingSpring(stiffness: 300, damping: 30)` 实现无回弹手感

3. **遮罩层**：`Color.black.opacity(0.15/0.35)` 两级透明度，点击即收回面板

4. **布局适配**：面板底部使用 `offset(y:)` 对齐屏幕底部，ScrollView 底部分配 `panelState.height(in:) + 16` 的 padding 防止内容被遮挡

5. **Material 背景**：使用 `.regularMaterial` 替代硬编码白色，自动适配 Dark Mode

## 踩坑记录

- `DragGesture` 的 `predictedEndTranslation` 用于计算松手后的预判终点，速度检测需取 `predictedEndTranslation.height - translation.height` 而非 `velocity` 属性
- `GeometryReader` 需包裹整个 `ZStack` 而非仅面板，否则 `offset(y:)` 计算基于面板自身而非屏幕坐标系
