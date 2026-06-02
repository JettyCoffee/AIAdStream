# Dark Mode 适配：硬编码颜色系统性迁移

## 背景

项目经过多轮迭代，共 21 处硬编码了 `.background(.white)`，另有 4 处使用 `Color(red: 0.97, green: 0.97, blue: 0.97)` 作为页面背景。这些颜色在 Light Mode 下表现正常，但在 Dark Mode 下会出现白色方块，严重破坏视觉一致性。

## 问题

SwiftUI 提供了语义化颜色的概念（如 `Color(.systemBackground)`），它们会自动根据当前 color scheme 切换浅色/深色值。但项目中大量使用了字面量颜色，需要在不改变 Light Mode 视觉效果的前提下适配 Dark Mode。

## 方案对比

### 方案 A：自定义 ColorScheme 感知的 Color 扩展

定义一系列自定义语义颜色，通过 `@Environment(\.colorScheme)` 手动切换。

```swift
extension Color {
    static var cardBackground: Color {
        Color(light: .white, dark: Color(red: 0.11, green: 0.11, blue: 0.12))
    }
    static var pageBackground: Color {
        Color(light: Color(red: 0.97, green: 0.97, blue: 0.97), 
              dark: .black)
    }
}
```

**优点**：完全控制颜色值，可以精确匹配设计稿

**缺点**：
- 需要为每个使用场景定义新常量，增加维护负担
- 可能与系统未来版本的 dark mode 颜色方案不一致
- 新增 UI 组件时容易遗漏

### 方案 B：使用系统语义化颜色（采用）

直接使用 iOS 内置的语义化颜色，替换所有硬编码值。

| 原值 | 替换为 | 适用场景 |
|------|--------|----------|
| `.white` | `Color(.systemBackground)` | 卡片、信息区背景 |
| `.white` | `.regularMaterial` | 底部固定栏、Tab 栏 |
| `Color(red: 0.97, ...)` | `Color(.systemGroupedBackground)` | 页面级背景（ScrollView 后方） |
| `Color(red: 0.95, ...)` | `Color(.systemGray6)` | 输入框、嵌入区域背景 |

**优点**：
- 零维护成本，自动跟随系统行为
- 与 iOS 第一方 App 视觉一致
- 仅需替换颜色值，不改变视图结构

**缺点**：
- 无法精确控制 dark mode 下的具体色值
- `.regularMaterial` 有模糊效果，性能略高于纯色背景

## 最终方案

采用方案 B。执行策略：

1. **卡片容器**（`cardStyle()` modifier）：`.white` → `Color(.systemBackground)`，保持 Light Mode 下白色卡片效果，Dark Mode 下自动切换为深灰
2. **底部固定栏和输入区**（AdDetailView bottomBar, DraggableAIPanel 底部输入）：`.white` → `.regularMaterial`，提供半透明材质效果
3. **页面背景**（FeedView, AnalyticsDashboardView, AdDetailView AI sheet）：`Color(red: 0.97...)` → `Color(.systemGroupedBackground)`
4. **嵌套输入框**：`Color(red: 0.95...)` → `Color(.systemGray6)`

涉及文件 8 个，共 25 处颜色替换。全部通过 `Replace All` 批量操作完成，构建一次通过。

## 设计要点

- **材质 vs 纯色**：底部栏用 `.regularMaterial` 而非 `.systemBackground`，因为底部栏需要与上方滚动内容形成层次区分，材质效果天然提供这种视觉分离
- **语义层次**：页面 → groupedBackground → 卡片 → systemBackground → 嵌入区 → systemGray6，形成 4 级视觉深度
- **向后兼容**：替换后 Light Mode 视觉效果与原始设计几乎无差异（`.systemBackground` 在 light mode 下即白色）
