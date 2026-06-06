# iOS 26 Liquid Glass 集成 & 详情页 AI 面板架构演进

## 背景

iOS 26 引入了 Liquid Glass 设计语言，SwiftUI 提供 `.glassEffect()` API。项目需要在详情页实现一个悬浮 AI 助手迷你播放器（类似 Apple Music 底部播放控件），同时重构原有的三态拖拽面板架构。

## 问题

### 问题 1：Liquid Glass 兼容性策略

iOS 26 的 `.glassEffect()` 在低版本系统不可用，直接使用会导致编译错误或 crash。需要一套优雅的降级方案。

### 问题 2：DraggableAIPanel 架构复杂度

旧版 `DraggableAIPanel` 将三种职责耦合在一个组件中：
- 折叠态：InteractionBar（点赞/收藏/分享）+ AI 触发条
- 展开态：完整聊天界面
- 手势系统：DragGesture + velocity 检测 + 弹性吸附

这导致：
- 组件臃肿（约 370 行），职责不清
- InteractionBar 属于内容层，不应嵌在底部面板中
- 自定义拖拽手势与系统 sheet detents 功能重叠

### 问题 3：AI 聊天 Markdown 渲染缺失

LLM 返回的消息常包含 Markdown 格式（粗体、斜体、列表、代码块等），但两个聊天界面（详情页 AI + 搜索页 AI）均使用纯文本 `Text(content)` 渲染，无法展示富文本格式。

### 问题 4：参数名遮蔽 Swift 标准库函数

在 `miniBarRow` 中，参数名 `max` 与 Swift 内置函数 `max(_:_:)` 同名，导致编译器报错 `cannot call value of non-function type 'Int'`。

## 方案对比

### 方案 A：Liquid Glass 降级 — 内联 `#available` vs 提取 Modifier

| 维度 | 内联 `#available` | 提取 `.glassBackground()` modifier |
|---|---|---|
| 代码复用 | 每次使用需重复 if/else | 一行调用，DRY |
| 可维护性 | 低，改一处需改全部 | 高，修改集中一处 |
| 类型安全 | 相同 | 相同 |
| 编译影响 | 无 | 无 |

**选择**：提取 `.glassBackground()` ViewModifier，一处定义、全局复用。

### 方案 B：AI 面板架构 — 保持拖拽 vs 拆分为 MiniPlayer + Sheet

| 维度 | 保持 DraggableAIPanel | 拆分为 AIMiniPlayer + Sheet |
|---|---|---|
| 手势自由度 | 三态连续拖拽 | 仅系统 sheet detents（medium/large） |
| 代码复杂度 | 高（Gesture + offset 计算） | 低（safeAreaInset + .sheet） |
| iOS 原生感 | 自定义，与系统行为不一致 | 完全原生 |
| InteractionBar 位置 | 嵌在底部面板中 | 独立在内容区标题下方 |
| 维护成本 | 高 | 低 |

**选择**：拆分为三个独立组件：
- `InteractionBar` → 移至 `AdDetailView` 标题下方（内容层）
- `AIMiniPlayer` → 悬浮底部胶囊（导航层，类似 Apple Music）
- `AIChatSheetContent` → Sheet 弹出聊天（模态层）

### 方案 C：Markdown 渲染 — 自定义解析器 vs SwiftUI 内置 `Text(.init(_:))`

| 维度 | 自定义 Markdown 解析 | `Text(.init(content))` |
|---|---|---|
| 支持语法 | 完全可控（表格、任务列表等） | 基础语法（粗体/斜体/链接/代码） |
| 实现成本 | 高（需手写解析器或引入库） | 零（iOS 15+ 内置） |
| 流式兼容 | 可做 partial 渲染 | 不兼容（标记未闭合时异常） |
| 包体积 | +50~200KB（引入库） | 无影响 |

**选择**：使用 `Text(.init(content))` 渲染已完成的消息，流式输出保持纯文本。兼顾成本和实效。

## 最终方案

### 1. Liquid Glass 集成

```swift
// 定义可复用的降级 modifier
private struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }
}
```

### 2. 详情页 AI 面板新架构

```
AdDetailView
├── ScrollView（内容区）
│   ├── mediaSection
│   ├── headerSection
│   │   ├── sponsor + channel
│   │   ├── tags
│   │   ├── title
│   │   └── InteractionBar ← 从底部面板移至此
│   └── brandSection
└── .safeAreaInset(edge: .bottom)
    └── AIMiniPlayer ← 轻量悬浮胶囊
        └── onTap → .sheet(isPresented:)
            └── AIChatSheetContent ← 完整聊天界面
```

### 3. Markdown 双轨渲染

- **已完成消息**：`Text(.init(msg.content))` — 解析 Markdown
- **流式消息**：`Text(streamingContent)` — 纯文本，避免标记断裂

### 4. 变量命名约束

参数名避免使用 Swift 标准库函数名（`max`、`min`、`filter`、`map` 等），改用 `maxValue`、`minCount` 等带语义后缀的命名。

## 设计要点

1. **GlassEffectContainer 无需使用**：该容器用于多个 glass 元素融合（morphing），迷你播放器仅单个元素，直接使用 `.glassEffect()` 即可
2. **safeAreaInset 优于 ZStack 布局**：`.safeAreaInset(edge: .bottom)` 自动处理底部安全区 + 内容内边距，比手动 GeometryReader 偏移计算更简洁
3. **Sheet detents 优于自定义拖拽**：原生 `.presentationDetents([.medium, .large])` + `.presentationBackgroundInteraction(.enabled)` 提供系统级拖拽体验，代码量减少 80%
4. **contentShape 不可省略**：使用 `.buttonStyle(.plain)` 的自定义 Button 必须显式 `.contentShape(Rectangle())` 才能全区域响应点击
