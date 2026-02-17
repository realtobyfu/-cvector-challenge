import Foundation
import SwiftData
import SwiftUI

@Observable
final class ItemViewModel {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createNote(title: String = "Untitled Note") -> Item {
        let item = Item(title: title, type: .note)
        item.status = .active
        modelContext.insert(item)
        try? modelContext.save()
        return item
    }

    func assignToBoard(_ item: Item, board: Board) {
        if !item.boards.contains(where: { $0.id == board.id }) {
            item.boards.append(board)
            item.updatedAt = .now
            try? modelContext.save()
        }
    }

    func removeFromBoard(_ item: Item, board: Board) {
        item.boards.removeAll { $0.id == board.id }
        item.updatedAt = .now
        try? modelContext.save()
    }

    func updateItem(_ item: Item, title: String, content: String?) {
        item.title = title
        item.content = content
        item.updatedAt = .now
        try? modelContext.save()
    }

    func deleteItem(_ item: Item) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    /// Quick capture: detects URL vs plain text, creates appropriate Item
    func captureItem(input: String) -> Item {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme.lowercased()),
           url.host != nil {
            // URL input — detect article vs video
            let itemType: ItemType = Self.isVideoURL(trimmed) ? .video : .article
            let item = Item(title: trimmed, type: itemType)
            item.status = .inbox
            item.sourceURL = trimmed
            modelContext.insert(item)
            try? modelContext.save()
            return item
        } else {
            // Plain text — create a note
            let title = String(trimmed.prefix(80))
            let item = Item(title: title, type: .note)
            item.status = .inbox
            item.content = trimmed
            modelContext.insert(item)
            try? modelContext.save()
            return item
        }
    }

    private static func isVideoURL(_ urlString: String) -> Bool {
        let lower = urlString.lowercased()
        return lower.contains("youtube.com/watch")
            || lower.contains("youtu.be/")
            || lower.contains("vimeo.com/")
            || lower.contains("twitch.tv/")
    }
}
