import SwiftUI

enum Channel: String, Codable, CaseIterable {
    case featured
    case ecommerce
    case local

    var displayName: String {
        switch self {
        case .featured: return "精选"
        case .ecommerce: return "电商"
        case .local: return "本地"
        }
    }

    var accentColor: Color {
        switch self {
        case .featured: return Color(red: 0.48, green: 0.64, blue: 0.86)
        case .ecommerce: return Color(red: 0.91, green: 0.61, blue: 0.54)
        case .local: return Color(red: 0.55, green: 0.72, blue: 0.60)
        }
    }
}
