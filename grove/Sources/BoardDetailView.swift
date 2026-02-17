import SwiftUI
import SwiftData

struct BoardDetailView: View {
    let board: Board

    var body: some View {
        VStack(spacing: 0) {
            if board.items.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(board.title)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: board.icon ?? "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(board.title)
                .font(.title2)
                .fontWeight(.semibold)
            Text("No items yet. Add items to this board to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemsList: some View {
        List(board.items) { item in
            HStack(spacing: 10) {
                Image(systemName: item.type.iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .fontWeight(.medium)
                    if let url = item.sourceURL {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
}
