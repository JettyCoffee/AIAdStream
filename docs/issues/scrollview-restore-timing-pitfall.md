# ScrollView 位置恢复的时序陷阱：onChange 提前消费标记位

## 背景

信息流中使用 `ScrollViewReader.scrollTo` 在从详情页返回时恢复滚动位置。通过 `simultaneousGesture(TapGesture())` 在 NavigationLink 触发时保存当前卡片 ID，返回时滚动到该 ID。

## 问题

### 现象
1. 从详情页返回时，卡片被强制滚动到顶部（而非原位置）
2. 偶尔位置恢复完全失效，停留在顶部
3. 点击 Tag 筛选后位置会随机跳动

### 原因链

**核心问题：`onChange(of: needsScrollRestore)` 在导航发生前触发**

```swift
// ❌ 错误实现
.simultaneousGesture(
    TapGesture().onEnded {
        savedScrollAdId = ad.id
        needsScrollRestore = true  // (A) 标记位置已保存
    }
)

.onChange(of: needsScrollRestore) { _, _ in
    restoreScrollPosition(proxy: proxy)  // (B) 立即触发！
}
```

时序：
1. 用户点击卡片 → `simultaneousGesture` 设置 `needsScrollRestore = true`
2. `onChange(of: needsScrollRestore)` **立即触发**（同一 run loop）
3. `restoreScrollPosition` 执行 `scrollTo(target)` → 卡片被移到顶部
4. `needsScrollRestore = false` → **标记位被消费**
5. NavigationLink **然后** 推送到详情页
6. 用户返回 → `.onAppear` 触发 → `needsScrollRestore` 已是 `false` → **不恢复位置**

**附加问题**：`simultaneousGesture` 在任何点击（包括 InteractionBar 按钮）都触发，覆盖了正确的目标 ID。

## 方案对比

| 方案 | 描述 | 优缺点 |
|------|------|--------|
| A. 延迟恢复 | `DispatchQueue.main.asyncAfter(.now() + 0.5)` 延迟 | 不可靠，导航时机不确定 |
| B. `onAppear` 单独恢复 | 取消 `onChange`，仅在 `.onAppear` 中恢复 | 简洁，但需确认 onAppear 在 NavigationStack 中的触发时机 |
| C. 程序化导航 | 使用 `NavigationPath` + `navigationDestination` | 完全可控，但改动大 |

## 最终方案：B - 仅 onAppear 恢复 + 筛选期间跳过

### 设计要点
1. **移除 `onChange(of: needsScrollRestore)` 触发** — 这是根因
2. **仅在 `ScrollView.onAppear` 中恢复** — NavigationStack 返回时 `.onAppear` 可靠触发
3. **筛选期间跳过恢复** — 检查 `viewModel.isFiltering` 避免位置跳动
4. **频道切换时重置** — `savedScrollAdId = nil; needsScrollRestore = false`

```swift
// ✅ 修复后
.simultaneousGesture(
    TapGesture().onEnded {
        savedScrollAdId = ad.id
        needsScrollRestore = true  // 仅标记，不触发恢复
    }
)

// ScrollView 上
.onAppear {
    // 从详情页返回时恢复，筛选/加载期间跳过
    guard needsScrollRestore, !viewModel.isFiltering,
          let target = savedScrollAdId else { return }
    needsScrollRestore = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        proxy.scrollTo(target)  // 默认锚点：最小滚动距离使目标可见
    }
}
```

### 为什么 `scrollTo(target)` 不指定 anchor
默认行为是 "scroll the minimum amount to make the item visible"，比 `.top`（强制移到顶部）更符合用户预期。
