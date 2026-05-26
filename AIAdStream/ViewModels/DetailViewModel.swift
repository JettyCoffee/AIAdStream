import SwiftUI
import Combine

@MainActor
final class DetailViewModel: ObservableObject {
    @Published var ad: AdItem
    @Published var summary: String?
    @Published var tags: [AITag] = []

    private let aiService = AIService()
    private let persistence = DataPersistence.shared

    init(ad: AdItem) {
        self.ad = ad
        loadCachedAIData()
        loadInteractionState()
    }

    func loadAIData() async {
        let cached = persistence.loadAICache()[ad.id]
        if cached == nil || cached?.summary == nil {
            summary = await aiService.generateSummary(for: ad)
            if let idx = persistence.loadAICache()[ad.id]?.tags {
                tags = idx
            }
        }
        if tags.isEmpty {
            tags = await aiService.generateTags(for: ad)
        }
    }

    func interactionState() -> InteractionState {
        persistence.loadInteractionState(for: ad.id)
    }

    private func loadCachedAIData() {
        if let cached = persistence.loadAICache()[ad.id] {
            summary = cached.summary
            tags = cached.tags
        }
    }

    private func loadInteractionState() {
        _ = persistence.loadInteractionState(for: ad.id)
    }
}
