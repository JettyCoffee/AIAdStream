# 种子数据库升级导致数据清空：Schema 迁移的 DROP TABLE 策略

## 背景

App 使用 bundled SQLite 作为种子库，首次启动时复制到 Documents 工作库。种子库从 v2 升级 v3 时 schema 发生变化：移除 `cta_text`、`creative_format` 等列，从 18 列精简为 9 列。

升级部署后，app 信息流完全空白。

## 问题

### 现象
- 工作库 `ad_items` 表 0 行，`ad_tags` 表 0 行
- 种子库正常（450 条广告），Bundle 中包含
- 控制台日志显示 seeding 完成但实际数据未写入

### 原因链
1. `createTables()` 使用 `CREATE TABLE IF NOT EXISTS` — 旧表存在则跳过
2. 旧表 schema 有 `cta_text TEXT NOT NULL` 等列
3. `seedIfNeeded()` 检测到版本升级，`DELETE FROM ad_items` 清空数据
4. 新 INSERT 语句仅指定 9 列（不包含 `cta_text`）
5. SQLite 对未指定的 NOT NULL 列尝试使用默认值 → 无默认值 → **INSERT 静默失败**
6. 结果：旧数据被清空，新数据写入失败 → 空数据库

```sql
-- 旧表（v2）
CREATE TABLE ad_items (
    ...,
    cta_text TEXT NOT NULL,   -- 新 INSERT 不提供
    ai_summary TEXT,           -- v3 改为 NOT NULL
    creative_format TEXT,
    ...
);

-- 新 INSERT（v3）— 只有 9 列，cta_text 缺失 → 失败
INSERT INTO ad_items (id, title, description, image_url, video_url,
    card_type, channel, sponsor, ai_summary) VALUES (...);
```

## 方案对比

| 方案 | 描述 | 优缺点 |
|------|------|--------|
| A. ALTER TABLE 逐列修改 | 使用 `ALTER TABLE RENAME/ADD/DROP` 迁移 | 需多次 ALTER，SQLite 不支持 DROP COLUMN（旧版本），复杂且易出错 |
| B. INSERT 提供所有旧列 | 在 INSERT 中为已删除的列提供默认值 | 侵入代码，每次改 schema 都要维护废弃列的占位值 |
| C. DROP TABLE 后重建 | 重新播种时直接 DROP 旧表，`CREATE TABLE` 建新表 | 干净彻底，零维护成本；缺点是旧表数据全丢（但种子重播本就要替换全部数据） |

## 最终方案：C - DROP TABLE + 重建

### 设计要点
1. **`createTables()` 拆分为两个方法**：`createAdTables()`（ad_items/ad_tags）和 `createInteractionAndAnalyticsTables()`（交互/分析表）
2. **重新播种时**：先 `DROP TABLE IF EXISTS` → 再 `createAdTables()` → 最后 INSERT 种子数据
3. **首次安装时**：正常走 `CREATE TABLE IF NOT EXISTS` 路径

```swift
// DatabaseManager.seedIfNeeded()
if adCount > 0 {
    // 清除旧表（含旧 schema），确保兼容
    executeUpdate("DROP TABLE IF EXISTS ad_tags") { _ in }
    executeUpdate("DROP TABLE IF EXISTS ad_items") { _ in }
    createAdTables()  // 以最新 schema 重建
}
// 后续正常 INSERT 种子数据...
```

### 为什么交互表不需要 DROP
`interaction_states` 和 `analytics_events` 存储用户行为数据，schema 未变更，不应随种子升级清空。只重建广告数据表。
