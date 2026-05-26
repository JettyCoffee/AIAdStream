import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [AdItem] = []
    @Published var isSearching = false
    @Published var hasSearched = false

    private let dataService = AdDataService()
    private let searchService = SearchService()
    private let analytics = AnalyticsService.shared

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isSearching = true
        hasSearched = true
        analytics.track(.search, metadata: query)

        let dbResults = dataService.searchAds(query: trimmed, channel: nil)
        if !dbResults.isEmpty {
            results = dbResults
        } else {
            let allAds = dataService.allAdsAcrossChannels()
            results = await searchService.search(query: trimmed, ads: allAds)
        }
        isSearching = false
    }
}
