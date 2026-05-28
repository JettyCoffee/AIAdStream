# Qwen 端侧模型部署与 NL→Tags 检索方案

## 背景

训练营可选功能要求"使用 Qwen 免费版本部署在本地"，实现对话式搜索：用户用自然语言描述想看的广告（如"适合学生党的性价比高的蓝牙耳机"），系统理解语义并返回匹配结果。

当前项目有一个纯基于规则的关键词匹配"AI"搜索（`AIService.conversationalSearch`），只能做简单的关键词包含判断，无法理解"学生党"→"学生,平价,数码"这类语义映射。

## 问题

1. **搜索无语义理解**：规则引擎仅做文本包含匹配，"适合上班族"无法匹配到标注了"办公"标签的广告
2. **模型选型与集成**：iOS 端侧运行 LLM 需要选择合适的推理框架，模型文件大（350MB+），需考虑下载和加载策略
3. **搜索延迟**：端侧推理有延迟，需设计合适的 fallback 机制

## 方案对比

### 方案 A：MLX Swift（Apple 原生 ML 框架）

使用 Apple 的 MLX 框架加载 Qwen3-0.6B 4-bit 量化模型，在本地完成 NL→Tags 的推理。

**优点**：
- Apple 官方维护，与 iOS/macOS 深度集成
- 支持 Metal GPU 加速
- Swift 原生 API，与项目语言一致
- 社区活跃，Qwen3 模型有官方 MLX 格式

**缺点**：
- 需添加 SPM 依赖（`mlx-swift` + `mlx-swift-lm`）
- 模型文件约 350MB，需下载策略
- 首次推理需加载模型，有冷启动延迟
- SPM 依赖在 CLI 构建环境无法自动解析（需 Xcode UI）

### 方案 B：CoreML 转换

使用 `mlx-lm convert` 或 `coremltools` 将 Qwen3 转换为 CoreML 格式，通过 Apple 原生 CoreML API 推理。

**优点**：
- 纯 Apple API，无额外依赖
- CoreML 模型可内置于 Bundle
- 与 Xcode 工具链深度集成

**缺点**：
- 模型转换步骤复杂（需 Python 环境 + MLX/CoreML tools）
- Qwen3 的 Transformer 架构在 CoreML 中的算子支持有限
- 转换后模型精度可能下降

### 方案 C：llama.cpp Swift 封装

通过 llama.cpp 的 Swift 绑定运行 GGUF 格式的 Qwen 模型。

**优点**：
- GGUF 格式成熟，模型获取方便
- llama.cpp 在端侧推理领域广受验证
- 轻量级，无重型框架依赖

**缺点**：
- 需额外封装 Swift 层
- Metal 加速不如 MLX 原生
- 社区维护的 Swift 绑定版本滞后

### 方案 D：无需模型 - 数据库标签词汇模糊匹配

利用项目中 1192 个已有标签建立词汇映射，用编辑距离（Levenshtein）+ 包含匹配实现伪语义搜索。

**优点**：
- 零依赖，即刻可用
- 无下载延迟
- 覆盖大部分常见查询

**缺点**：
- 无法处理标签词汇外的查询
- 不能理解复杂语义关系

## 最终方案：A（MLX Swift 为主）+ D（fallback）

```
用户查询
    │
    ▼
QwenService.extractTags(query)
    │
    ├── MLX 模型就绪？
    │   └── Qwen 推理: "适合学生党耳机" → ["数码", "学生党", "通勤"]
    │
    └── 未就绪？
        └── fuzzyMatchTags: 从 1192 个标签中模糊匹配
    │
    ▼
DatabaseManager.fetchAdsByTags(tags, channel, limit)
    │
    ▼
返回按匹配标签数量降序的广告列表
```

### 实现细节

**QwenService 条件编译**：
```swift
#if canImport(MLX)
import MLX
// MLX 推理代码
#endif
```

MLX 推理代码在 `#if` 块中，当 SPM 依赖未添加时自动降级为 fallback 模糊匹配。

**模型下载策略**：
- 首次启动检查 `Documents/Qwen3-0.6B-4bit/config.json` 是否存在
- 不存在则从 HuggingFace CDN 下载 4 个文件（config.json, tokenizer.json, tokenizer_config.json, model.safetensors）
- 下载使用 URLSession 异步请求，失败静默降级

**Prompt 设计（few-shot）**：
```
你是一个广告标签提取器。给定用户的自然语言搜索查询，提取用于检索广告的中文标签。
只输出逗号分隔的标签，不要有任何其他文字。每个标签不超过4个汉字。

示例输入：适合学生党的性价比高的蓝牙耳机
示例输出：数码,学生党,通勤,音乐

示例输入：适合送礼的高端美妆护肤品
示例输出：美妆,送礼,都市丽人,时尚
```

仅输出逗号分隔标签（无 JSON 包裹），`temperature=0.1` 确保确定性输出，`maxTokens=50` 限制响应长度。

**多标签 SQL 检索**：
```sql
SELECT a.*, COUNT(DISTINCT t.name) AS match_count
FROM ad_items a
JOIN ad_tags t ON a.id = t.ad_id
WHERE t.name IN (?, ?, ?, ?)
GROUP BY a.id
ORDER BY match_count DESC
LIMIT ?
```

占位符数量动态生成，匹配标签越多排名越靠前。

**fallback 模糊匹配**：
- 从数据库获取全部 1192 个标签
- 对每个标签与查询关键词计算三层分数：精确匹配 (10分) > 包含匹配 (5分) > 编辑距离相似度 (2分)
- 取 top 5 标签用于检索
- 编辑距离阈值 0.5（相似度 > 50% 才纳入）

## 设计要点

1. **条件编译不阻塞构建**：`#if canImport(MLX)` 确保在 MLX 未添加时项目可正常编译运行
2. **模型按需下载**：不在 App Bundle 中内置 350MB 模型，首次使用才下载，节省包体积
3. **fallback 无感知**：`QwenService.extractTags` 对外接口统一，调用方不关心用的是 MLX 还是 fallback
4. **SQL IN 动态绑定**：`tags.map { _ in "?" }.joined(separator: ",")` 自动生成正确数量的占位符
5. **Prompt 工程**：few-shot 示例覆盖数码、美妆、亲子、运动等主要品类，引导模型输出与数据库标签对齐的词汇
