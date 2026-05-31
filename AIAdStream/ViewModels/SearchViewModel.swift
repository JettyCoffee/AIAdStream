import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var messages: [ChatMessage] = []
    @Published var recommendedAds: [AdItem] = []
    @Published var isStreaming = false
    @Published var streamingContent = ""
    @Published var errorMessage: String?

    private var aiService: AIService {
        AIService(apiKey: Constants.DeepSeek.apiKey)
    }
    private let analytics = AnalyticsService.shared
    private var streamTask: Task<Void, Never>?

    var hasConversation: Bool { !messages.isEmpty }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let userMsg = ChatMessage(role: .user, content: trimmed)
        messages.append(userMsg)
        inputText = ""
        errorMessage = nil
        isStreaming = true
        streamingContent = ""

        analytics.track(.search, metadata: trimmed)

        streamTask?.cancel()
        streamTask = Task {
            do {
                var fullContent = ""
                for try await event in aiService.chat(history: messages) {
                    switch event {
                    case .contentDelta(let delta):
                        fullContent += delta
                        streamingContent = fullContent

                    case .toolCallStart(let toolName):
                        streamingContent = toolName == "search_ads"
                            ? "正在搜索匹配的广告..."
                            : "正在获取信息..."

                    case .toolCallResult(let result):
                        if !result.ads.isEmpty {
                            recommendedAds = result.ads
                        } else if let detail = result.detailAd {
                            recommendedAds = [detail]
                        }

                    case .done(let finalContent):
                        fullContent = finalContent
                        streamingContent = ""
                        let assistantMsg = ChatMessage(
                            role: .assistant,
                            content: fullContent.isEmpty ? "已为你找到相关广告 👇" : fullContent
                        )
                        messages.append(assistantMsg)
                    }
                }
                isStreaming = false
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isStreaming = false
                    streamingContent = ""
                }
            }
        }
    }

    func clearConversation() {
        streamTask?.cancel()
        messages = []
        recommendedAds = []
        isStreaming = false
        streamingContent = ""
        errorMessage = nil
    }
}
