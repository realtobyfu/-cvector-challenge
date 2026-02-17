import Foundation
import SwiftData

enum ItemType: String, Codable {
    case article
    case video
    case note
    case courseLecture

    var iconName: String {
        switch self {
        case .article: "doc.richtext"
        case .video: "play.rectangle"
        case .note: "note.text"
        case .courseLecture: "graduationcap"
        }
    }
}

enum ItemStatus: String, Codable {
    case inbox
    case active
    case archived
    case dismissed
}

@Model
final class Item {
    var id: UUID
    var title: String
    var type: ItemType
    var status: ItemStatus
    var sourceURL: String?
    var content: String?
    var thumbnail: Data?
    var engagementScore: Float
    var metadata: [String: String]
    var createdAt: Date
    var updatedAt: Date

    // Spaced resurfacing fields
    var lastResurfacedAt: Date?
    var resurfaceIntervalDays: Int
    var resurfaceCount: Int
    var lastEngagedAt: Date?
    var isResurfacingPaused: Bool

    @Relationship(inverse: \Board.items) var boards: [Board]
    @Relationship(inverse: \Tag.items) var tags: [Tag]
    @Relationship(deleteRule: .cascade, inverse: \Annotation.item) var annotations: [Annotation]
    @Relationship(deleteRule: .cascade, inverse: \Connection.sourceItem) var outgoingConnections: [Connection]
    @Relationship(deleteRule: .cascade, inverse: \Connection.targetItem) var incomingConnections: [Connection]

    /// Whether this item is eligible for the resurfacing queue.
    /// Requires at least one annotation or connection.
    var isResurfacingEligible: Bool {
        !annotations.isEmpty || !outgoingConnections.isEmpty || !incomingConnections.isEmpty
    }

    /// Next resurfacing date based on lastResurfacedAt + interval, or lastEngagedAt + interval.
    var nextResurfaceDate: Date? {
        guard isResurfacingEligible, !isResurfacingPaused, status == .active else { return nil }
        let referenceDate = lastResurfacedAt ?? lastEngagedAt ?? createdAt
        return Calendar.current.date(byAdding: .day, value: resurfaceIntervalDays, to: referenceDate)
    }

    /// Whether this item is overdue for resurfacing.
    var isResurfacingOverdue: Bool {
        guard let nextDate = nextResurfaceDate else { return false }
        return nextDate <= .now
    }

    init(title: String, type: ItemType) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.status = .inbox
        self.sourceURL = nil
        self.content = nil
        self.thumbnail = nil
        self.engagementScore = 0
        self.metadata = [:]
        self.createdAt = .now
        self.updatedAt = .now
        self.lastResurfacedAt = nil
        self.resurfaceIntervalDays = 7
        self.resurfaceCount = 0
        self.lastEngagedAt = nil
        self.isResurfacingPaused = false
        self.boards = []
        self.tags = []
        self.annotations = []
        self.outgoingConnections = []
        self.incomingConnections = []
    }
}
