import Foundation

// MARK: - AI Service (DeepSeek Orchestration)

final class AIService {
    private let deepSeek: DeepSeekService
    private let db = DatabaseManager.shared

    init(apiKey: String) {
        self.deepSeek = DeepSeekService(apiKey: apiKey)
    }

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
}
