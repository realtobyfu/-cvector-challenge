import Foundation
import SwiftData
import SwiftUI

@Observable
final class BoardViewModel {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createBoard(title: String, icon: String?, color: String?) {
        let maxSortOrder = fetchMaxSortOrder()
        let board = Board(title: title, icon: icon, color: color)
        board.sortOrder = maxSortOrder + 1
        modelContext.insert(board)
        try? modelContext.save()
    }

    func updateBoard(_ board: Board, title: String, icon: String?, color: String?) {
        board.title = title
        board.icon = icon
        board.color = color
        try? modelContext.save()
    }

    func deleteBoard(_ board: Board) {
        modelContext.delete(board)
        try? modelContext.save()
    }

    func reorderBoards(_ boards: [Board]) {
        for (index, board) in boards.enumerated() {
            board.sortOrder = index
        }
        try? modelContext.save()
    }

    func moveBoard(from source: IndexSet, to destination: Int, in boards: [Board]) {
        var ordered = boards
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, board) in ordered.enumerated() {
            board.sortOrder = index
        }
        try? modelContext.save()
    }

    private func fetchMaxSortOrder() -> Int {
        let descriptor = FetchDescriptor<Board>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        let boards = (try? modelContext.fetch(descriptor)) ?? []
        return boards.first?.sortOrder ?? -1
    }
}
