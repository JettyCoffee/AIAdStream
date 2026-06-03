import SwiftUI

// MARK: - Panel State

/// 面板展开状态（保留以备将来使用）
/// 当前详情页已改用 AIMiniPlayer + AIChatSheetContent（Sheet 模式）
enum AIPanelState: CGFloat, CaseIterable {
    case bar    = 0
    case medium = 1
    case large  = 2

    func height(in geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        switch self {
        case .bar:    return 72
        case .medium: return screenHeight * 0.38
        case .large:  return screenHeight * 0.78
        }
    }

    var dragIndicatorVisible: Bool {
        self != .bar
    }
}

// MARK: - Draggable AI Panel（已废弃）

/// 旧版可拖动 AI 面板，已被 AIMiniPlayer + AIChatSheetContent 取代。
/// 迷你播放器（AIMiniPlayer）处理折叠态，聊天内容通过 .sheet 弹出 AIChatSheetContent。
/// 此 struct 保留作为参考，如需恢复拖动面板方案可基于此重建。
struct DraggableAIPanel: View {
    let ad: AdItem
    @ObservedObject var viewModel: DetailViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    @Binding var panelState: AIPanelState

    var body: some View {
        // 已废弃：使用 AIMiniPlayer + sheet(isPresented:) { AIChatSheetContent } 替代
        EmptyView()
    }
}
