import SwiftUI

struct ChannelTabBar: View {
    @Binding var selectedChannel: Channel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Channel.allCases, id: \.self) { channel in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedChannel = channel
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(channel.displayName)
                            .font(.system(size: 16, weight: selectedChannel == channel ? .semibold : .regular))
                            .foregroundColor(selectedChannel == channel ? .primary : Constants.Colors.secondaryText)

                        Capsule()
                            .fill(selectedChannel == channel ? channel.accentColor : .clear)
                            .frame(width: 20, height: 3)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.white)
    }
}
