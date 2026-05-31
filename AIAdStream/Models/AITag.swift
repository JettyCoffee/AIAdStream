enum TagCategory: String, Codable, CaseIterable {
    case category
    case style
    case audience

    var displayName: String {
        switch self {
        case .category: return "品类"
        case .style: return "风格"
        case .audience: return "受众"
        }
    }
}

struct AITag: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: TagCategory
}
