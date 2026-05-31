import Foundation

// MARK: - DeepSeek API Service

final class DeepSeekService {
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1/chat/completions"
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = "deepseek-chat") {
        self.apiKey = apiKey
        self.model = model
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Streaming Chat

    func streamChat(
        messages: [ChatMessage],
        tools: [ToolDef]?
    ) -> AsyncThrowingStream<ChatChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = try self.buildRequestBody(messages: messages, tools: tools)
                    var request = URLRequest(url: URL(string: baseURL)!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = body

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw DeepSeekError.invalidResponse
                    }
                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines.prefix(10) { errorBody += line }
                        throw DeepSeekError.httpError(httpResponse.statusCode, errorBody)
                    }

                    // ── Parse SSE stream ──
                    var accumulatedTC: [Int: (id: String, name: String, args: String)] = [:]

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        if jsonStr == "[DONE]" {
                            flushToolCallsIfAny(&accumulatedTC, to: continuation)
                            continuation.finish()
                            return
                        }

                        guard let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]]
                        else { continue }

                        for choice in choices {
                            let delta = choice["delta"] as? [String: Any]
                            let finishReason = choice["finish_reason"] as? String

                            if let content = delta?["content"] as? String, !content.isEmpty {
                                continuation.yield(.content(content))
                            }

                            if let tcDeltas = delta?["tool_calls"] as? [[String: Any]] {
                                for tc in tcDeltas {
                                    let idx = tc["index"] as? Int ?? 0
                                    var cur = accumulatedTC[idx] ?? (id: "", name: "", args: "")
                                    if let id = tc["id"] as? String { cur.id = id }
                                    if let fn = tc["function"] as? [String: Any] {
                                        if let name = fn["name"] as? String { cur.name = name }
                                        if let args = fn["arguments"] as? String { cur.args += args }
                                    }
                                    accumulatedTC[idx] = cur
                                }
                            }

                            if finishReason == "tool_calls" {
                                flushToolCallsIfAny(&accumulatedTC, to: continuation)
                                continuation.finish()
                                return
                            }
                            if finishReason == "stop" {
                                continuation.finish()
                                return
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func buildRequestBody(messages: [ChatMessage], tools: [ToolDef]?) throws -> Data {
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map(\.apiDict),
            "stream": true,
        ]
        if let tools = tools {
            body["tools"] = try tools.map { tool in
                let data = try JSONEncoder().encode(tool)
                return try JSONSerialization.jsonObject(with: data)
            }
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func flushToolCallsIfAny(
        _ accumulated: inout [Int: (id: String, name: String, args: String)],
        to continuation: AsyncThrowingStream<ChatChunk, Error>.Continuation
    ) {
        guard !accumulated.isEmpty else { return }
        let calls = accumulated.sorted(by: { $0.key < $1.key }).map {
            ChatChunk.ToolCallDelta(id: $0.value.id, name: $0.value.name, arguments: $0.value.args)
        }
        continuation.yield(.toolCalls(calls))
        accumulated.removeAll()
    }
}

// MARK: - Chat Chunk (streaming event)

enum ChatChunk {
    case content(String)
    case toolCalls([ToolCallDelta])

    struct ToolCallDelta {
        let id: String
        let name: String
        let arguments: String
    }
}

// MARK: - Errors

enum DeepSeekError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case invalidToolArguments

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无法连接到 DeepSeek 服务"
        case .httpError(let code, let body):
            return "请求失败 (\(code)): \(body.prefix(200))"
        case .invalidToolArguments:
            return "工具参数解析失败"
        }
    }
}

// MARK: - ChatMessage → API Dict

private extension ChatMessage {
    var apiDict: [String: Any] {
        var dict: [String: Any] = ["role": role.rawValue]

        switch role {
        case .assistant where toolCalls != nil && !(toolCalls!.isEmpty):
            dict["content"] = content.isEmpty ? nil : content
            dict["tool_calls"] = toolCalls!.map { tc in
                [
                    "id": tc.id,
                    "type": tc.type,
                    "function": [
                        "name": tc.function.name,
                        "arguments": tc.function.arguments,
                    ],
                ] as [String: Any]
            }
        case .tool:
            dict["content"] = content
            dict["tool_call_id"] = toolCallId ?? ""
        default:
            dict["content"] = content
        }
        return dict
    }
}
