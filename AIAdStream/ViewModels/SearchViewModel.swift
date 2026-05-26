import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [AdItem] = []
    @Published var isSearching = false
    @Published var hasSearched = false

    private let searchService = SearchService()
    private let analytics = AnalyticsService.shared

    func search(ads: [AdItem]) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = ads
            return
        }
        isSearching = true
        hasSearched = true
        results = await searchService.search(query: query, ads: ads)
        analytics.track(.search, metadata: query)
        isSearching = false
    }
}
