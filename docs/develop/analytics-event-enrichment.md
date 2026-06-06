# 埋点事件富化：JSON Metadata 模式

## 背景
AIAdStream 的埋点系统最初仅记录 `(type, adId, channel, timestamp)` 四元组，在数据看板中展示时，事件描述为 "like feat_0"，用户无法理解其含义。同时，互动状态变更（点赞/收藏/分享的开关和计数变化）没有被追踪，无法分析用户行为路径。

## 问题
1. **事件不可读**：仅存储 adId，展示层不知道广告标题、赞助商、卡片类型等上下文
2. **状态变更无痕**：用户取消点赞、重复收藏等行为无法追溯，数据分析缺少状态变更维度的信息
3. **扩展性受限**：未来如果要新增追踪维度（如停留时长、滚动深度），需要修改事件表结构

## 方案对比

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| A. metadata JSON 列 | 在 `metadata` 文本字段中以 JSON 存储 `AdContext` 和 `StateChangeInfo` | 动态schema，无需迁移；存储灵活，不同事件类型可存不同字段 | 无法在SQL层做结构化查询；JSON解析有性能开销 |
| B. 宽表展开 | 将 `adTitle` / `adSponsor` / `cardType` 展开为独立列 | SQL可直接WHERE过滤；查询性能最优 | 表结构臃肿；新增字段需migration；历史事件中广告信息可能变更 |
| C. JOIN 查询 | 事件表仅存 `adId`，展示时 JOIN 广告主表获取标题 | 数据一致性好；广告信息变更自动反映 | 广告可能被删除导致事件丢失上下文；跨表JOIN增加查询复杂度 |

## 最终方案

选择 **方案 A（metadata JSON 列）**，并在此基础上构建富化层。

### 数据模型

**存储层** — `AnalyticsEvent`（不变）：
- `metadata: String?` — 存储 JSON，写入时编码，读取时不解码（仅做过滤）

**富化层** — `EnrichedEvent`（展示专用）：
- `AdContext`：从 metadata 解码，包含 `adTitle` / `adSponsor` / `cardType`
- `StateChangeInfo`：从 metadata 解码，包含 `field` / `from` / `to`
- `displayText`：根据事件类型+上下文生成中文可读描述

### 编码策略

```
普通事件 (impression/click/like/collect/share):
  metadata = { "adTitle": "Nike Air Max", "adSponsor": "Nike", "cardType": "bigImage" }

状态变更事件 (stateChange):
  metadata = {
    "context": { "adTitle": "...", ... },
    "stateChange": { "field": "isLiked", "from": "false", "to": "true" }
  }

标签点击事件 (tagClick):
  metadata = { ..., "extra": "运动鞋" }
  → 序列化后用 "|" 分隔 context JSON 和 extra 字符串
```

### 解析容错

`parseAdContext` 方法同时兼容两种格式：
1. **复合格式** `{"context": "...", "stateChange": "..."}` — 通过 key 检测，提取 `context` 子JSON
2. **普通格式** `{"adTitle": "...", ...}` — 直接解析为 `AdContext`

## 设计要点
- **写入时富化、读取时解析**：事件写入时即将广告上下文快照编码进 metadata，避免广告被删除后事件上下文丢失
- **展示层二次映射**：`stateChangeFieldName` 将字段名映射为中文（isLiked → 点赞，isCollected → 收藏）
- **性能考量**：metadata 解析在 `enrichedEvents()` 返回时一次性完成，View 层直接消费 `EnrichedEvent` 对象，避免重复解析
- **扩展性**：新增追踪字段只需在 `AdContext` / `StateChangeInfo` 中添加属性，无需修改数据库表结构
