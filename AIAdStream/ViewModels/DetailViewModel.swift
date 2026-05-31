import SwiftUI
import Combine

@MainActor
final class DetailViewModel: ObservableObject {
    let ad: AdItem
    @Published var tags: [AITag] = []

    // AI Chat
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatInput = ""
    @Published var isChatStreaming = false
    @Published var chatStreamingContent = ""
    @Published var chatRecommendedAds: [AdItem] = []
    @Published var chatErrorMessage: String?

    private var aiService: AIService {
        AIService(apiKey: Constants.DeepSeek.apiKey)
    }
    private let db = DatabaseManager.shared
    private var streamTask: Task<Void, Never>?

    init(ad: AdItem) {
        self.ad = ad
        loadCachedTags()
    }

    private func loadCachedTags() {
        tags = db.tagsForAd(ad.id)
    }

    // MARK: - AI Chat

    func sendChatMessage() {
        let trimmed = chatInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isChatStreaming else { return }

        let userMsg = ChatMessage(role: .user, content: trimmed)
        chatMessages.append(userMsg)
        chatInput = ""
        chatErrorMessage = nil
        isChatStreaming = true
        chatStreamingContent = ""
        chatRecommendedAds = []

        streamTask?.cancel()
        streamTask = Task {
            do {
                var fullContent = ""
                for try await event in aiService.chatAboutAd(ad, history: chatMessages) {
                    switch event {
                    case .contentDelta(let delta):
                        fullContent += delta
                        chatStreamingContent = fullContent

                    case .toolCallStart(let toolName):
                        chatStreamingContent = toolName == "get_similar_ads"
                            ? "正在查找相似广告..."
                            : "正在获取信息..."

                    case .toolCallResult(let result):
                        if !result.ads.isEmpty {
                            chatRecommendedAds = result.ads
                        }

                    case .done(let finalContent):
                        fullContent = finalContent
                        chatStreamingContent = ""
                        chatMessages.append(ChatMessage(
                            role: .assistant,
                            content: fullContent.isEmpty ? "已为你找到相关信息 👇" : fullContent
                        ))
                    }
                }
                isChatStreaming = false
            } catch {
                if !Task.isCancelled {
                    chatErrorMessage = error.localizedDescription
                    isChatStreaming = false
                    chatStreamingContent = ""
                }
            }
        }
    }
}
