import SwiftUI

struct TagChipView: View {
    let tag: AITag
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            Text(tag.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Constants.Colors.tagBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct TagRow: View {
    let tags: [AITag]
    var onTagTap: ((AITag) -> Void)?

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.tagSpacing) {
                    ForEach(tags) { tag in
                        TagChipView(tag: tag) {
                            onTagTap?(tag)
                        }
                    }
                }
                .padding(.horizontal, Constants.horizontalPadding)
            }
        }
    }
}
