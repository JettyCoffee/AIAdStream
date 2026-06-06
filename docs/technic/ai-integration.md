# AI 集成方案

## 概述

App 有三处用到 DeepSeek 大模型：

1. **广告摘要和智能标签**（离线预生成）：种子数据库里的 `ai_summary` 字段和 `ad_tags` 表由模型预生成，App 运行时直接读取，不实时调用 API
2. **对话式广告搜索**：用户输入自然语言，模型通过 Function Calling 自动调用本地搜索、相似推荐和联网查询
3. **趣味解读**：对单条广告进行幽默段子、打油诗等风格的改写，结果以打字机动画展示

## 方案对比：AI 集成架构

### 方案 A：ViewModel 直接调用 API

每个 ViewModel 里写 `URLSession` 请求，自己解析响应。

**缺点明显**：Function Calling 的 Tool Call → Execute → Continue 循环、SSE 流解析、错误处理和重试逻辑会在多个 ViewModel 中重复。而且 V

ViewModel 不应该知道 API 的传输细节。

### 方案 B：通过本地模型服务

部署一个本地模型（如 Qwen），App 通过 HTTP 调用。

**不选的原因**：部署和运维成本高，模拟器上跑不起来，答辩时演示不方便。课题要求里提到可以用 Qwen，但不是强制——DeepSeek API 的免费额度足够开发调试。

### 方案 C：Service 层封装 + AsyncThrowingStream（选用）

AI 功能拆为两层：

- **DeepSeekService**：纯粹的 HTTP 客户端，负责请求构造、SSE 流解析，对外暴露 `AsyncThrowingStream<ChatChunk, Error>`
- **AIService**：编排层，管理对话循环（最多 5 轮）、工具调用执行、限流、安全兜底，对外暴露 `AsyncThrowingStream<StreamEvent, Error>`

ViewModel 只和 AIService 打交道，不感知 HTTP 和 SSE。

## DeepSeekService：SSE 流式客户端

DeepSeek API 的 chat/completions 端点支持 `stream: true` 参数，响应是 SSE（Server-Sent Events）格式：

```
data: {"choices":[{"delta":{"content":"这"}}]}
data: {"choices":[{"delta":{"content":"几"}}]}
data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"search_ads"}}]}}]}
data: [DONE]
```

Swift 端用 `URLSession.shared.bytes(for:)` 逐行读取：

```swift
let (bytes, response) = try await session.bytes(for: request)
for try await line in bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let jsonStr = String(line.dropFirst(6))
    if jsonStr == "[DONE]" { break }
    // 解析 JSON, yield ChatChunk
}
```

为什么不用 Combine 的 `dataTaskPublisher`？因为 `AsyncThrowingStream` 和 async/await 的协作更自然——上游是 `for try await` 循环，下游是 `for try await event in aiService.chat(...)`，整条链路没有 callback 嵌套。

## AIService：Function Calling 编排

核心循环：

```
用户消息 → DeepSeek API (流式)
  ├── content delta → 流式输出文本给 UI
  ├── tool_calls delta → 累积工具调用参数
  └── finish_reason: "tool_calls"
      ↓
  执行工具调用（本地 DB 查询 / 联网搜索）
      ↓
  将 tool result 作为 tool 角色消息追加到对话历史
      ↓
  继续下一轮（最多 5 轮）
      ↓
  finish_reason: "stop" → 输出最终总结 + 广告卡片数据
```

关键实现细节：

### Tool Call 的累积解析

DeepSeek 在流式模式下，tool_calls 的数据是分多个 chunk 到达的，需要按 index 累积：

```swift
var accumulatedTC: [Int: (id: String, name: String, args: String)] = [:]
// 每个 delta 追加参数
cur.args += delta.args
// receive finish_reason="tool_calls" 时 flush
```

### 安全兜底机制

首轮如果 LLM 没有调用任何工具就直接输出了文本（finish_reason="stop" 且 toolCallDeltas 为空），`AIService` 会自动执行一次 `search_ads` 并注入结果。这个兜底确保了即使用户表达了不明确的需求，也能返回一些广告——而不是让对话直接结束。

触发条件有两个限制：
- `hasCalledTools == false`（只兜底首轮）
- 跳过纯闲聊场景（用户消息存在即可）

### Rate Limiter

```swift
final class RateLimiter {
    private let minInterval: TimeInterval = 2.0
    func shouldProceed() -> Bool { ... }
}
```

简单的基于时间戳的限流器，NSLock 保证线程安全。DeepSeek 免费版的 QPS 限制很低，不加限流容易触发 429。

## 工具定义

注册了 5 个工具，结构如下：

| 工具名 | 参数 | 功能 |
|--------|------|------|
| `search_ads` | query, channel?, limit? | 搜索本地广告数据库 |
| `get_ad_detail` | ad_id (必填) | 获取单条广告完整信息 |
| `get_similar_ads` | ad_id (必填), limit? | 按标签匹配相似广告 |
| `web_search` | query (必填) | DuckDuckGo Lite 联网搜索 |
| `ai_enhance_ad` | ad_id (必填), style? | 获取广告数据用于趣味改写 |

工具定义通过 `JSONSchema` 枚举构造，支持 object/string/integer/array 四种类型和必填字段标记。

联网搜索的实现比较轻量——抓取 DuckDuckGo Lite 的 HTML 并用正则提取结果摘要，没有引入完整的搜索 API。这个选择的考量是：不需要额外注册 API Key，而且广告相关搜索（品牌、评测）用通用搜索引擎足够，不需要 Google Custom Search 那样的精确度。

## System Prompt 约束策略

System Prompt 里写了 9 条回复规则，核心目标是防止 LLM 的"过度展示"倾向：

1. **必须先调用 search_ads**：防止 LLM 凭训练数据"编造"广告
2. **广告由视觉卡片展示**：让 LLM 知道不需要在文本中描述广告
3. **1-2 句简洁总结**：防止 LLM 输出 200 字以上的营销文案
4. **禁止列表格式**：严禁数字编号、Markdown 标题、表格
5. **禁止重复卡片信息**：广告标题、品牌名已显示在卡片上，不用重复

这些约束来自调优过程中的观察——LLM 默认会在回复中把搜索到的广告逐条列出来，格式工整、信息详尽，看起来不错但和信息流 UI 的视觉卡片严重重复。用户看到的是"卡片已展示 + 文本又列一遍"。通过这组规则约束后，模型的行为变成"卡片先行 + 一句话总结"。

## AI 趣味解读

趣味解读的流程和对话搜索不同——它不需要 Function Calling 循环，走的是简单的一次性请求：

1. 用户点击卡片上的"趣味解读"按钮
2. FeedViewModel 构造一个带风格的 prompt 发给 AIService.chat()
3. 模型返回改写后的文本
4. 结果缓存到 `enhancedContents: [String: String]` 字典，key 是 adId
5. EnhanceBanner 组件以打字机动画逐字展示（Timer 每 0.04 秒显示一个字）

缓存策略：同一个 adId 不会重复请求。点击"换一种"时会重新请求（因为 prompt 不变但模型可能给出不同输出）。

## API Key 安全存储

API Key 通过 iOS Keychain 存储，使用 `kSecClassGenericPassword` + `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`：

```swift
final class KeychainService {
    func save(_ value: String) throws { ... }
    func load() throws -> String? { ... }
}
```

`Constants.DeepSeek.apiKey` 是一个计算属性，读取时优先从 Keychain 拿，找不到时检查 UserDefaults 是否有旧 Key（兼容迁移），都没有就返回空字符串。

为什么不直接用 `@AppStorage`？UserDefaults 以 plist 明文存磁盘，任何能访问 App 沙盒的进程都能读到。Keychain 用硬件加密，系统级隔离，这才是 API Key 该待的地方。
