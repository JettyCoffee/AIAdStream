# 卡片组件标准化：从三套重复代码到统一组件体系

## 背景

三种广告卡片（BigImageCard / SmallImageCard / VideoCard）各自独立实现标题、摘要、标签、互动栏等子组件，导致：
1. 样式调整需同时修改三个文件
2. Bug 修复容易遗漏某一卡片类型
3. 新增组件（如 AI 摘要）需三处重复添加

## 问题

BigImageCard 和 VideoCard 的底部信息区代码几乎完全相同（sponsor → title → aiSummary → tags → InteractionBar），SmallImageCard 是水平布局但子组件逻辑一致。修改一张卡片时需同步另外两张。

## 方案对比

| 方案 | 描述 | 优缺点 |
|------|------|--------|
| A. 卡片继承 | 抽象 BaseCard，三类卡片继承 | SwiftUI View 不适合继承模式，编译器支持差 |
| B. ViewModifier | 将共同样式提取为 Modifier | 难以处理可变子视图布局 |
| C. 独立子组件 + cardStyle | 将原子组件提取为独立 View，用 `cardStyle()` modifier 统一外观 | 清晰、可组合、零耦合 |

## 最终方案：C - 独立子组件 + 容器 Modifier

### 组件架构
```
CardComponents.swift
├── CardInfoSection         // 大卡片底部信息区（纵向布局）
├── CardInfoSectionCompact  // 小卡片右侧信息区（已合并为大卡片组件）
├── CardSponsorLabel        // 赞助商名称
├── CardTitleLabel          // 广告标题
├── CardAISummary           // AI 摘要（sparkles icon + 紫色背景）
├── CardTagRow              // 标签横向滚动行
├── CardVideoOverlay        // 视频播放控制叠加层
└── cardStyle()             // View extension：白色背景 + 12pt 圆角 + 阴影 + 16pt padding
```

### 使用方式
```swift
// BigImageCard
VStack {
    imageArea
    CardInfoSection(ad: ad, interactionState: $state, ...)
}
.cardStyle()  // 统一的卡片外观

// SmallImageCard  
HStack {
    thumbnail
    CardInfoSectionCompact(ad: ad, ...)  // 右侧信息区
}
.cardStyle()

// VideoCard
VStack {
    videoArea
    CardSponsorLabel(...)
    CardTitleLabel(...)
    CardTagRow(...)
    CardAISummary(...)
    InteractionBar(...)
}
.cardStyle()
```

### 设计要点
- **原子性**：每个子组件只做一件事，`CardSponsorLabel` 只管文字样式
- **Slot 模式**：大卡片用 `CardInfoSection` 整体接入，小卡片和视频卡因其布局差异较大，按需组合原子组件
- **cardStyle() modifier**：替代 `CardContainer<Content>` 泛型包装，API 更简洁
- **Tag 位置标准化**：一律放在 AI 摘要上方（代码统一，视觉一致）
