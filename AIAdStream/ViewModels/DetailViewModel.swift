import SwiftUI
import Combine

@MainActor
final class DetailViewModel: ObservableObject {
    @Published var ad: AdItem
    @Published var summary: String?
    @Published var tags: [AITag] = []

    private let aiService = AIService()
    private let db = DatabaseManager.shared

    init(ad: AdItem) {
        self.ad = ad
        loadCachedAIData()
    }

    func loadAIData() async {
        if summary == nil {
            summary = await aiService.generateSummary(for: ad)
        }
        if tags.isEmpty {
            tags = await aiService.generateTags(for: ad)
        }
    }

    private func loadCachedAIData() {
        summary = db.fetchAd(by: ad.id)?.aiSummary
        tags = db.tagsForAd(ad.id)
    }
}
