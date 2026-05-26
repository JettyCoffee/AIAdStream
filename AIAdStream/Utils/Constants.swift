import SwiftUI

enum Constants {
    static let pageSize = 10
    static let cardSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 12
    static let tagSpacing: CGFloat = 8

    struct Colors {
        static let likeActive = Color(red: 0.94, green: 0.72, blue: 0.75)
        static let tagBackground = Color(red: 0.95, green: 0.95, blue: 0.96)
        static let separator = Color(red: 0.93, green: 0.93, blue: 0.94)
        static let secondaryText = Color(red: 0.55, green: 0.55, blue: 0.57)
    }

    static let videoPlayerPoolSize = 3
    static let impressionThreshold: TimeInterval = 1.0
}
