import SwiftUI

struct LazyImageView: View {
    let imageName: String
    let contentMode: ContentMode

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false
    @State private var taskRunning = false

    init(imageName: String, contentMode: ContentMode = .fill) {
        self.imageName = imageName
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image = loadedImage ?? ImageCache.shared.image(for: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loadFailed {
                placeholderView
            } else {
                placeholderView
                    .onAppear(perform: startLoad)
            }
        }
    }

    private func startLoad() {
        guard !taskRunning else { return }
        guard loadedImage == nil, ImageCache.shared.image(for: imageName) == nil else { return }

        // 用户创建的广告无图片 URL，保持默认占位状态（不显示错误图标）
        guard !imageName.isEmpty else { return }

        guard imageName.hasPrefix("https://") || imageName.hasPrefix("http://") else {
            loadFailed = true
            return
        }

        guard let url = URL(string: imageName) else {
            loadFailed = true
            return
        }

        taskRunning = true
        Task {
            defer { taskRunning = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    ImageCache.shared.setImage(image, for: imageName)
                    await MainActor.run {
                        self.loadedImage = image
                    }
                } else {
                    await MainActor.run { self.loadFailed = true }
                }
            } catch {
                await MainActor.run { self.loadFailed = true }
            }
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        let colors: [Color] = [
            Color(red: 0.78, green: 0.80, blue: 0.84),
            Color(red: 0.74, green: 0.70, blue: 0.74),
            Color(red: 0.70, green: 0.75, blue: 0.72),
            Color(red: 0.72, green: 0.74, blue: 0.78),
            Color(red: 0.76, green: 0.74, blue: 0.70),
        ]
        let colorIndex = abs(imageName.hashValue) % colors.count

        Rectangle()
            .fill(colors[colorIndex])
            .overlay {
                Image(systemName: loadFailed ? "photo.badge.exclamationmark" : "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
            }
    }
}
