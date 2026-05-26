import Foundation

final class DataPersistence {
    static let shared = DataPersistence()
    private let defaults = UserDefaults.standard

    private let interactionStatesKey = "interaction_states"
    private let analyticsEventsKey = "analytics_events"
    private let aiResultsKey = "ai_results_cache"

    private init() {}

    func saveInteractionState(_ state: InteractionState, for adId: String) {
        var states = loadAllInteractionStates()
        states[adId] = state
        if let data = try? JSONEncoder().encode(states) {
            defaults.set(data, forKey: interactionStatesKey)
        }
    }

    func loadInteractionState(for adId: String) -> InteractionState {
        loadAllInteractionStates()[adId] ?? InteractionState()
    }

    func loadAllInteractionStates() -> [String: InteractionState] {
        guard let data = defaults.data(forKey: interactionStatesKey),
              let states = try? JSONDecoder().decode([String: InteractionState].self, from: data)
        else { return [:] }
        return states
    }

    func saveAICache(_ results: [String: AICacheEntry]) {
        if let data = try? JSONEncoder().encode(results) {
            defaults.set(data, forKey: aiResultsKey)
        }
    }

    func loadAICache() -> [String: AICacheEntry] {
        guard let data = defaults.data(forKey: aiResultsKey),
              let cache = try? JSONDecoder().decode([String: AICacheEntry].self, from: data)
        else { return [:] }
        return cache
    }
}

struct AICacheEntry: Codable {
    let summary: String?
    let tags: [AITag]
}
