import Foundation

struct AdItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let imageURL: String
    let videoURL: String?
    let cardType: AdCardType
    let channel: Channel
    var tags: [AITag]
    var aiSummary: String?
    let sponsor: String
    let ctaText: String

    static func == (lhs: AdItem, rhs: AdItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AdPage: Codable {
    let ads: [AdItem]
    let hasMore: Bool
}
