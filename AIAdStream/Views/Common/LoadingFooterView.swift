import SwiftUI

struct LoadingFooterView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载中...")
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
