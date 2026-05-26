enum TagCategory: String, Codable, CaseIterable {
    case category
    case style
    case audience
    case scene

    var displayName: String {
        switch self {
        case .category: return "品类"
        case .style: return "风格"
        case .audience: return "受众"
        case .scene: return "场景"
        }
    }
}

struct AITag: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: TagCategory
}
