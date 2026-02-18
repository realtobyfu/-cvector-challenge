import Foundation
import SwiftData

/// Progress state for a learning path step.
enum LearningPathStepProgress: String, Codable, CaseIterable {
    case notStarted
    case read
    case reflected

    var displayName: String {
        switch self {
        case .notStarted: "Not Started"
        case .read: "Read"
        case .reflected: "Reflected"
        }
    }

    var systemImage: String {
        switch self {
        case .notStarted: "circle"
        case .read: "circle.lefthalf.filled"
        case .reflected: "checkmark.circle.fill"
        }
    }
}

/// A single step in a learning path.
@Model
final class LearningPathStep {
    var id: UUID
    var learningPath: LearningPath?
    var item: Item?
    var reason: String
    var position: Int
    var isSynthesisStep: Bool
    var progress: LearningPathStepProgress

    init(item: Item?, reason: String, position: Int, isSynthesisStep: Bool = false) {
        self.id = UUID()
        self.item = item
        self.reason = reason
        self.position = position
        self.isSynthesisStep = isSynthesisStep
        self.progress = .notStarted
    }
}

/// An ordered learning path generated from items within a topic (board or tag).
@Model
final class LearningPath {
    var id: UUID
    var title: String
    var topic: String
    var board: Board?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LearningPathStep.learningPath)
    var steps: [LearningPathStep]

    init(title: String, topic: String, board: Board? = nil) {
        self.id = UUID()
        self.title = title
        self.topic = topic
        self.board = board
        self.createdAt = .now
        self.updatedAt = .now
        self.steps = []
    }
}
