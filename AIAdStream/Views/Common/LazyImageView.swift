import SwiftUI

struct LazyImageView: View {
    let imageName: String
    let contentMode: ContentMode

    init(imageName: String, contentMode: ContentMode = .fill) {
        self.imageName = imageName
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let cached = ImageCache.shared.image(for: imageName) {
                Image(uiImage: cached)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholderView
            }
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        let colors: [Color] = [
            Color(red: 0.93, green: 0.94, blue: 0.96),
            Color(red: 0.90, green: 0.86, blue: 0.89),
            Color(red: 0.86, green: 0.90, blue: 0.87),
            Color(red: 0.86, green: 0.88, blue: 0.92),
            Color(red: 0.91, green: 0.89, blue: 0.86),
        ]
        let colorIndex = abs(imageName.hashValue) % colors.count

        Rectangle()
            .fill(colors[colorIndex])
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.6))
            }
    }
}
