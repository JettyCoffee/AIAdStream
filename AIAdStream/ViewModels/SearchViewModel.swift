import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var items: [ConversationItem] = []
    @Published var isStreaming = false
    @Published var streamingContent = ""
    @Published var errorMessage: String?
    @Published var showHistory = false

    /// 当前对话中 LLM 可见的消息历史（不含广告卡片）
    var chatHistory: [ChatMessage] {
        items.compactMap(\.message).filter { $0.role != .system }
    }

    private var aiService: AIService {
        AIService(apiKey: Constants.DeepSeek.apiKey)
    }
    private let analytics = AnalyticsService.shared
    private let db = DatabaseManager.shared
    private var streamTask: Task<Void, Never>?

    /// 当前对话记录 ID（非 nil 表示已有持久化记录）
    private var currentRecordId: String?

    var hasConversation: Bool { !items.isEmpty }

    // MARK: - Send Message

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let userMsg = ChatMessage(role: .user, content: trimmed)
        items.append(.message(userMsg))
        inputText = ""
        errorMessage = nil
        isStreaming = true
        streamingContent = ""

        analytics.track(.search, metadata: trimmed)

        streamTask?.cancel()
        streamTask = Task {
            // 本轮 LLM 返回的广告（在 done 时附加到 items）
            var pendingAds: [AdItem] = []

            do {
                var fullContent = ""
                for try await event in aiService.chat(history: chatHistory) {
                    switch event {
                    case .contentDelta(let delta):
                        fullContent += delta
                        streamingContent = fullContent

                    case .toolCallStart:
                        // 不覆盖已有流式内容，保持状态提示简短
                        if streamingContent.isEmpty {
                            streamingContent = "..."
                        }

                    case .toolCallResult(let result):
                        pendingAds = result.ads
                        if let detail = result.detailAd {
                            pendingAds = [detail]
                        }

                    case .done(let finalContent):
                        fullContent = finalContent
                        streamingContent = ""

                        // 广告卡片先行
                        if !pendingAds.isEmpty {
                            items.append(.adCards(pendingAds))
                        }

                        // LLM 的 1-2 句总结紧跟其后
                        let summary = finalContent.trimmingCharacters(in: .whitespaces)
                        if !summary.isEmpty {
                            items.append(.message(ChatMessage(role: .assistant, content: summary)))
                        } else if pendingAds.isEmpty {
                            items.append(.message(ChatMessage(role: .assistant, content: "未找到匹配的广告。")))
                        }
                        pendingAds = []
                    }
                }
                isStreaming = false
                persistConversation()
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isStreaming = false
                    streamingContent = ""
                }
            }
        }
    }

    // MARK: - Conversation Lifecycle

    func clearConversation() {
        streamTask?.cancel()
        items = []
        isStreaming = false
        streamingContent = ""
        errorMessage = nil
        currentRecordId = nil
    }

    func loadConversation(_ record: ConversationRecord) {
        clearConversation()
        currentRecordId = record.id

        for persisted in record.items {
            switch persisted {
            case .message(let role, let content):
                guard let msgRole = MessageRole(rawValue: role) else { continue }
                items.append(.message(ChatMessage(role: msgRole, content: content)))
            case .adCards(let adIds):
                let ads = adIds.compactMap { db.fetchAd(by: $0) }
                if !ads.isEmpty {
                    items.append(.adCards(ads))
                }
            }
        }
        showHistory = false
    }

    // MARK: - Persistence

    private static let historyKey = "conversation_history"
    private static let maxHistoryCount = 20

    private func persistConversation() {
        let chatItems = items
        guard !chatItems.isEmpty else { return }

        let title = chatItems
            .compactMap(\.message)
            .first(where: { $0.role == .user })?
            .content
            .prefix(30) ?? "对话"

        let persistedItems: [PersistedItem] = chatItems.compactMap { item in
            switch item {
            case .message(let msg):
                return .message(role: msg.role.rawValue, content: msg.content)
            case .adCards(let ads):
                return .adCards(adIds: ads.map(\.id))
            }
        }

        var history = loadHistory()
        let record: ConversationRecord

        if let existingId = currentRecordId,
           let idx = history.firstIndex(where: { $0.id == existingId }) {
            record = ConversationRecord(id: existingId, title: String(title), date: Date(), items: persistedItems)
            history[idx] = record
        } else {
            let newId = UUID().uuidString
            record = ConversationRecord(id: newId, title: String(title), date: Date(), items: persistedItems)
            currentRecordId = newId
            history.insert(record, at: 0)
        }

        // 限制条数
        if history.count > Self.maxHistoryCount {
            history = Array(history.prefix(Self.maxHistoryCount))
        }

        saveHistory(history)
    }

    static func loadAllHistory() -> [ConversationRecord] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let records = try? JSONDecoder().decode([ConversationRecord].self, from: data)
        else { return [] }
        return records
    }

    private func loadHistory() -> [ConversationRecord] {
        Self.loadAllHistory()
    }

    private func saveHistory(_ history: [ConversationRecord]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
    }

    static func deleteHistory(_ id: String) {
        var history = loadAllHistory()
        history.removeAll { $0.id == id }
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}
