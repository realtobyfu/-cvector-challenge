import Foundation
import SwiftData

@MainActor
final class AnnotationMigrationService {
    private static let migratedKey = "grove.annotationsMigrated"

    static var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: migratedKey)
    }

    static func migrateIfNeeded(context: ModelContext) {
        guard !hasMigrated else { return }

        let descriptor = FetchDescriptor<Annotation>()
        guard let annotations = try? context.fetch(descriptor), !annotations.isEmpty else {
            UserDefaults.standard.set(true, forKey: migratedKey)
            return
        }

        for annotation in annotations {
            guard let item = annotation.item else { continue }

            let nextPosition = (item.reflections.map(\.position).max() ?? -1) + 1
            let block = ReflectionBlock(
                item: item,
                blockType: .keyInsight,
                content: annotation.content,
                highlight: annotation.highlight,
                position: nextPosition,
                videoTimestamp: annotation.position
            )
            block.createdAt = annotation.createdAt
            context.insert(block)
            item.reflections.append(block)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: migratedKey)
    }
}
