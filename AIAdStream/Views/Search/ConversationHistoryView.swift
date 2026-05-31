import SwiftUI

struct ConversationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ConversationRecord) -> Void

    @State private var records: [ConversationRecord] = []
    @State private var deleteConfirmId: String?

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
            .navigationTitle("历史对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .onAppear { records = SearchViewModel.loadAllHistory() }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(Constants.Colors.secondaryText)
            Text("暂无历史对话")
                .font(.system(size: 16))
                .foregroundColor(Constants.Colors.secondaryText)
            Text("开始一次新的 AI 搜索，对话会自动保存")
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.secondaryText.opacity(0.7))
            Spacer()
        }
    }

    private var listView: some View {
        List {
            ForEach(records) { record in
                Button {
                    onSelect(record)
                } label: {
                    historyRow(record)
                }
            }
            .onDelete { indexSet in
                for i in indexSet {
                    SearchViewModel.deleteHistory(records[i].id)
                }
                records = SearchViewModel.loadAllHistory()
            }
        }
        .listStyle(.plain)
    }

    private func historyRow(_ record: ConversationRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(formatDate(record.date))
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.secondaryText)

                Text("·")
                    .foregroundColor(Constants.Colors.secondaryText)

                Text("\(record.items.count) 条消息")
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.secondaryText)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
