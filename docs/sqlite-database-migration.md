# SQLite 数据库迁移与线程安全

## 背景
App 最初使用内存中的 mock 数据和 UserDefaults JSON 持久化。随着数据量和查询复杂度增长（标签过滤、全文搜索、跨频道查询），需要引入结构化数据库。

## 问题
1. **数据持久化**: UserDefaults 不适合存储结构化关联数据（广告-标签 一对多关系）
2. **查询效率**: 内存数组 filter 无法利用索引，模糊搜索和 JOIN 查询需要多次遍历
3. **线程安全**: SQLite3 C API 非线程安全，多 Tab 并发访问需要同步机制
4. **数据来源**: Kaggle 数据集因网络限制无法直接下载

## 方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| Core Data | 原生框架，对象图管理 | 学习曲线陡，与 SwiftUI 配合需额外配置 |
| SwiftData | iOS 17+ 原生，声明式 | 部署目标需匹配，对复杂查询支持有限 |
| SQLite3 直连 | 零依赖，完全可控，查询灵活 | 需手写 SQL，C API 较底层 |
| GRDB | Swift 原生封装，类型安全 | 第三方依赖，不符合原生组件要求 |

## 最终方案
选用 **SQLite3 C API 直连**，基于以下原因：
- 零外部依赖，完全符合 CLAUDE.md 原生组件要求
- 对复杂查询（LIKE、JOIN、聚合）的完全控制
- WAL 模式提供并发读性能
- 串行 DispatchQueue 保证线程安全

## 设计要点
- 所有 DB 操作通过 `dbQueue`（串行队列）同步执行，消除竞态条件
- WAL 模式允许并发读不阻塞写操作
- 外键约束确保 ad_tags 与 ad_items 的数据完整性
- 首次启动自动从 SeedDataGenerator 填充数据（基于 Digital Advertising Campaign Performance Dataset schema）
- 标签过滤通过 ad_tags JOIN 查询实现，避免 N+1 问题
