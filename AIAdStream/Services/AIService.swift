import Foundation

// MARK: - AI Service (DeepSeek Orchestration)

final class AIService {
    static let shared = AIService()

    private var deepSeek: DeepSeekService {
        DeepSeekService(apiKey: Constants.DeepSeek.apiKey)
    }
    private let db = DatabaseManager.shared
    private let rateLimiter = RateLimiter(minInterval: 2.0)

    private init() {}

    // MARK: - General Chat (Search Tab)

    /// 搜索页面对话：根据自然语言查询推荐广告
    func chat(
        history: [ChatMessage]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        chatLoop(systemPrompt: Constants.DeepSeek.systemPrompt, history: history)
    }

    // MARK: - Ad-specific Chat (Detail Page)

    /// 详情页面对话：围绕指定广告回答用户问题
    func chatAboutAd(
        _ ad: AdItem,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let tags = db.tagsForAd(ad.id).map(\.name).joined(separator: "、")
        let prompt = """
        你是一个智能广告助手，用户正在浏览以下广告的详情页：
        - ID：\(ad.id)
        - 标题：\(ad.title)
        - 品牌商：\(ad.sponsor)
        - 描述：\(ad.description)
        - 标签：\(tags)
        - 卡片类型：\(ad.cardType.rawValue)

        你可以使用 get_ad_detail 获取更多广告信息，使用 get_similar_ads 查找类似广告。
        保持回复简洁友好，使用中文。
        """
        return chatLoop(systemPrompt: prompt, history: history)
    }

    // MARK: - Chat Loop (with tool calling)

    private func chatLoop(
        systemPrompt: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // 预检：API Key 未配置
                guard !Constants.DeepSeek.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
                    continuation.finish(throwing: AIServiceError.apiKeyNotConfigured)
                    return
                }
                // 限流检查
                guard rateLimiter.shouldProceed() else {
                    continuation.finish(throwing: AIServiceError.rateLimited)
                    return
                }

                var messages = [ChatMessage(role: .system, content: systemPrompt)] + history

                for _ in 0..<5 {
                    var fullContent = ""
                    var toolCallDeltas: [ChatChunk.ToolCallDelta] = []

                    do {
                        for try await chunk in deepSeek.streamChat(
                            messages: messages,
                            tools: Constants.DeepSeek.tools
                        ) {
                            switch chunk {
                            case .content(let delta):
                                fullContent += delta
                                continuation.yield(.contentDelta(delta))
                            case .toolCalls(let calls):
                                toolCallDeltas = calls
                                for call in calls {
                                    continuation.yield(.toolCallStart(call.name))
                                }
                            }
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }

                    guard !toolCallDeltas.isEmpty else {
                        // LLM 未调用任何工具：回退为自动搜索数据库
                        if let lastUserMsg = history.last(where: { $0.role == .user }) {
                            let query = lastUserMsg.content
                            let (resultText, resultAds, _) = await executeTool(
                                name: "search_ads",
                                arguments: "{\"query\":\"\(query.replacingOccurrences(of: "\"", with: "\\\""))\"}"
                            )
                            // 回退结果同样追加到消息历史，确保 LLM 知晓已展示的广告
                            messages.append(ChatMessage(
                                role: .tool,
                                content: resultText,
                                toolCallId: "fallback_search"
                            ))
                            continuation.yield(.toolCallResult(ToolResult(
                                toolName: "search_ads",
                                ads: resultAds,
                                detailAd: nil
                            )))
                        }
                        continuation.yield(.done(fullContent))
                        continuation.finish()
                        return
                    }

                    // 将 assistant 消息（含 tool_calls）加入历史
                    let toolCalls = toolCallDeltas.map { delta in
                        ToolCall(
                            id: delta.id,
                            type: "function",
                            function: FunctionCall(name: delta.name, arguments: delta.arguments)
                        )
                    }
                    messages.append(ChatMessage(
                        role: .assistant,
                        content: fullContent,
                        toolCalls: toolCalls
                    ))

                    // 执行每个工具调用，并将结果回传
                    for tc in toolCalls {
                        let (resultText, resultAds, detailAd) = await executeTool(
                            name: tc.function.name,
                            arguments: tc.function.arguments
                        )
                        messages.append(ChatMessage(
                            role: .tool,
                            content: resultText,
                            toolCallId: tc.id
                        ))
                        // 通知 UI 层工具结果（携带结构化广告数据）
                        continuation.yield(.toolCallResult(ToolResult(
                            toolName: tc.function.name,
                            ads: resultAds,
                            detailAd: detailAd
                        )))
                    }
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Tool Execution

    /// 返回值：(给 LLM 的文本结果, 搜索结果广告列表, 详情广告)
    private func executeTool(
        name: String,
        arguments: String
    ) async -> (String, [AdItem], AdItem?) {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return ("参数解析失败", [], nil) }

        switch name {
        case "search_ads":
            let (text, ads) = executeSearchAds(json)
            return (text, ads, nil)
        case "get_ad_detail":
            let (text, ad) = executeGetAdDetail(json)
            return (text, ad.map { [$0] } ?? [], ad)
        case "get_similar_ads":
            let (text, ads) = executeGetSimilarAds(json)
            return (text, ads, nil)
        case "web_search":
            let text = await executeWebSearch(json)
            return (text, [], nil)
        case "ai_enhance_ad":
            let text = executeEnhanceAd(json)
            return (text, [], nil)
        default:
            return ("未知工具: \(name)", [], nil)
        }
    }

    private func executeSearchAds(_ args: [String: Any]) -> (String, [AdItem]) {
        let query = args["query"] as? String ?? ""
        let channel = args["channel"] as? String
        let limit = min(args["limit"] as? Int ?? 5, 10)

        let results = db.searchAds(query: query, channel: channel)
        let limited = Array(results.prefix(limit))

        guard !limited.isEmpty else {
            return ("未找到与「\(query)」匹配的广告。", [])
        }

        let adsJson = limited.map { ad -> [String: Any] in
            [
                "id": ad.id,
                "title": ad.title,
                "sponsor": ad.sponsor,
                "description": String(ad.description.prefix(80)),
                "cardType": ad.cardType.rawValue,
                "channel": ad.channel.rawValue,
            ]
        }
        let text = (try? JSONSerialization.data(
            withJSONObject: adsJson, options: .prettyPrinted
        )).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return (text, limited)
    }

    private func executeGetAdDetail(_ args: [String: Any]) -> (String, AdItem?) {
        guard let adId = args["ad_id"] as? String,
              let ad = db.fetchAd(by: adId)
        else { return ("未找到该广告。", nil) }

        let tags = db.tagsForAd(adId).map(\.name).joined(separator: "、")
        var detail: [String: Any] = [
            "id": ad.id,
            "title": ad.title,
            "sponsor": ad.sponsor,
            "description": ad.description,
            "cardType": ad.cardType.rawValue,
            "channel": ad.channel.rawValue,
            "tags": tags,
            "aiSummary": ad.aiSummary,
        ]

        let text = (try? JSONSerialization.data(
            withJSONObject: detail, options: .prettyPrinted
        )).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return (text, ad)
    }

    private func executeGetSimilarAds(_ args: [String: Any]) -> (String, [AdItem]) {
        guard let adId = args["ad_id"] as? String,
              let _ = db.fetchAd(by: adId)
        else { return ("未找到参考广告。", []) }

        let limit = min(args["limit"] as? Int ?? 3, 5)
        let tags = db.tagsForAd(adId).map(\.name)

        guard !tags.isEmpty else {
            return ("该广告暂无标签，无法查找相似广告。", [])
        }

        let similar = db.fetchAdsByTags(tags, channel: nil, limit: limit + 1)
            .filter { $0.id != adId }
            .prefix(limit)

        guard !similar.isEmpty else {
            return ("未找到相似广告。", [])
        }

        let adsJson = similar.map { ad -> [String: Any] in
            [
                "id": ad.id,
                "title": ad.title,
                "sponsor": ad.sponsor,
                "description": String(ad.description.prefix(80)),
            ]
        }
        let text = (try? JSONSerialization.data(
            withJSONObject: adsJson, options: .prettyPrinted
        )).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return (text, Array(similar))
    }

    /// 趣味改写广告：返回广告数据供 LLM 参考生成趣味内容
    private func executeEnhanceAd(_ args: [String: Any]) -> String {
        guard let adId = args["ad_id"] as? String,
              let ad = db.fetchAd(by: adId)
        else { return "未找到该广告。" }

        let style = args["style"] as? String ?? "funny"
        let tags = db.tagsForAd(adId).map(\.name).joined(separator: "、")
        let data: [String: Any] = [
            "adTitle": ad.title,
            "sponsor": ad.sponsor,
            "description": ad.description,
            "tags": tags,
            "requestedStyle": style,
            "styleGuide": styleGuide(for: style),
        ]
        return ((try? JSONSerialization.data(
            withJSONObject: data, options: .prettyPrinted
        )).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"
    }

    /// 风格指引：告诉 LLM 这个风格应该怎么改写
    private func styleGuide(for style: String) -> String {
        switch style {
        case "funny":
            return "用幽默诙谐的语气写一段广告推荐，可以加入网络热梗或反转，让读者会心一笑。控制在 80 字以内。"
        case "poetic":
            return "写一首四句打油诗来推广这个产品，押韵有趣，朗朗上口。"
        case "story":
            return "写一个 100 字以内的微型故事，自然地带出产品卖点，读起来像朋友圈故事。"
        case "slogan":
            return "生成 3 条创意广告标语，每条不超过 15 字，要求新颖、好记、有传播力。"
        default:
            return "用幽默诙谐的语气写一段广告推荐。控制在 80 字以内。"
        }
    }

    /// 联网搜索：使用 DuckDuckGo Lite 抓取搜索结果摘要
    private func executeWebSearch(_ args: [String: Any]) async -> String {
        guard let query = args["query"] as? String, !query.trimmingCharacters(in: .whitespaces).isEmpty
        else { return "搜索查询为空。" }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://lite.duckduckgo.com/lite/?q=\(encoded)") else {
            return "搜索 URL 构造失败。"
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                return "无法解析搜索结果。"
            }

            // 简易 HTML 解析：提取 <a> 标签内的标题和摘要
            var results: [(title: String, snippet: String)] = []
            let lines = html.components(separatedBy: "\n")
            for line in lines {
                // DuckDuckGo Lite 结果格式：<a href="...">标题</a><span>摘要</span>
                if let titleStart = line.range(of: "class=\"result-link\""),
                   let snippetStart = line.range(of: "class=\"result-snippet\"") {
                    let titlePart = String(line[titleStart.upperBound...])
                        .components(separatedBy: "<")
                        .first?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let snippetPart = String(line[snippetStart.upperBound...])
                        .components(separatedBy: "<")
                        .first?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let cleanTitle = titlePart.replacingOccurrences(of: ">", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if !cleanTitle.isEmpty {
                        results.append((title: cleanTitle, snippet: snippetPart))
                    }
                }
            }

            // 通用回退：提取所有链接文本（DuckDuckGo Lite 可能变更 HTML 结构）
            if results.isEmpty {
                let pattern = try? NSRegularExpression(
                    pattern: "<a[^>]*href=\"([^\"]*)\"[^>]*>([^<]+)</a>",
                    options: .caseInsensitive
                )
                if let pattern = pattern {
                    let range = NSRange(html.startIndex..., in: html)
                    let matches = pattern.matches(in: html, range: range)
                    for match in matches.prefix(5) {
                        if let textRange = Range(match.range(at: 2), in: html) {
                            let title = String(html[textRange])
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !title.isEmpty && title.count > 3 {
                                results.append((title: title, snippet: ""))
                            }
                        }
                    }
                }
            }

            guard !results.isEmpty else {
                return "未找到与「\(query)」相关的搜索结果。"
            }

            let summary = results.prefix(5).enumerated().map { i, r in
                "\(i + 1). \(r.title)\(r.snippet.isEmpty ? "" : " — \(r.snippet)")"
            }.joined(separator: "\n")

            return "联网搜索结果（\(query)）：\n\(summary)"
        } catch {
            return "联网搜索失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - AIService Errors

enum AIServiceError: LocalizedError {
    case apiKeyNotConfigured
    case rateLimited
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "请先在设置中配置 DeepSeek API Key"
        case .rateLimited:
            return "操作太频繁，请稍后再试"
        case .networkError(let detail):
            return "网络连接失败：\(detail)"
        }
    }
}

// MARK: - Rate Limiter

final class RateLimiter {
    private let minInterval: TimeInterval
    private var lastProceedTime: Date = .distantPast
    private let lock = NSLock()

    init(minInterval: TimeInterval = 2.0) {
        self.minInterval = minInterval
    }

    func shouldProceed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        guard now.timeIntervalSince(lastProceedTime) >= minInterval else {
            return false
        }
        lastProceedTime = now
        return true
    }
}
