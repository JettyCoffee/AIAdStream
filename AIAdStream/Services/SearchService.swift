import Foundation

final class SearchService {
    private let aiService = AIService()

    func search(query: String, ads: [AdItem]) async -> [AdItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return ads }
        return await aiService.conversationalSearch(query: query, ads: ads)
    }
}
