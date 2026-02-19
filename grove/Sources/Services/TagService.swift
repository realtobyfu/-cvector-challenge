import Foundation
import SwiftData

/// Represents a suggestion to merge two near-duplicate tags
struct TagMergeSuggestion: Identifiable {
    let id = UUID()
    let tag1: Tag
    let tag2: Tag
    let similarity: Double
    let reason: String
}

/// Represents a suggestion for parent-child hierarchy between tags
struct TagHierarchySuggestion: Identifiable {
    let id = UUID()
    let parentTag: Tag
    let childTag: Tag
    let reason: String
}

/// Protocol for tag service.
@MainActor
protocol TagServiceProtocol {
    func mergeTags(keep: Tag, remove: Tag)
    func findMergeSuggestions(from tags: [Tag]) -> [TagMergeSuggestion]
}

/// Service for tag analysis: duplicate detection, merging, hierarchy suggestions, and improved clustering
@MainActor
@Observable
final class TagService: TagServiceProtocol {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Near-Duplicate Detection

    /// Find tags that are near-duplicates based on string similarity
    func findMergeSuggestions(from tags: [Tag]) -> [TagMergeSuggestion] {
        var suggestions: [TagMergeSuggestion] = []
        let seen = NSMutableSet()

        for i in 0..<tags.count {
            for j in (i + 1)..<tags.count {
                let tag1 = tags[i]
                let tag2 = tags[j]

                // Skip if already has a parent-child relationship
                if tag1.parentTag?.id == tag2.id || tag2.parentTag?.id == tag1.id {
                    continue
                }

                let pairKey = [tag1.id.uuidString, tag2.id.uuidString].sorted().joined(separator: "-")
                if seen.contains(pairKey) { continue }

                let sim = Self.nameSimilarity(tag1.name, tag2.name)
                if sim >= AppConstants.Scoring.tagMergeSimilarity {
                    let reason = describeSimReason(tag1.name, tag2.name)
                    suggestions.append(TagMergeSuggestion(
                        tag1: tag1,
                        tag2: tag2,
                        similarity: sim,
                        reason: reason
                    ))
                    seen.add(pairKey)
                }
            }
        }

        return suggestions.sorted { $0.similarity > $1.similarity }
    }

    /// Compute string similarity between two tag names using normalized edit distance
    nonisolated static func nameSimilarity(_ a: String, _ b: String) -> Double {
        let s1 = normalize(a)
        let s2 = normalize(b)

        if s1 == s2 { return 1.0 }
        if s1.isEmpty || s2.isEmpty { return 0.0 }

        let distance = levenshteinDistance(s1, s2)
        let maxLen = max(s1.count, s2.count)
        return 1.0 - Double(distance) / Double(maxLen)
    }

    /// Normalize a tag name for comparison: lowercase, strip separators
    nonisolated static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    /// Levenshtein edit distance
    nonisolated static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,      // deletion
                    curr[j - 1] + 1,   // insertion
                    prev[j - 1] + cost // substitution
                )
            }
            prev = curr
        }

        return prev[n]
    }

    private func describeSimReason(_ a: String, _ b: String) -> String {
        let na = Self.normalize(a)
        let nb = Self.normalize(b)
        if na == nb {
            return "Same name with different separators"
        }
        if na.contains(nb) || nb.contains(na) {
            return "One name contains the other"
        }
        return "Very similar names"
    }

    // MARK: - Tag Merge

    /// Merge tag2 into tag1: moves all items from tag2 to tag1, then deletes tag2
    func mergeTags(keep: Tag, remove: Tag) {
        // Transfer all items from 'remove' to 'keep'
        for item in remove.items {
            if !keep.items.contains(where: { $0.id == item.id }) {
                keep.items.append(item)
            }
            item.tags.removeAll { $0.id == remove.id }
        }

        // Transfer child tags
        for child in remove.childTags {
            child.parentTag = keep
        }

        // Transfer smart board rules
        for board in remove.smartRuleBoards {
            if !board.smartRuleTags.contains(where: { $0.id == keep.id }) {
                board.smartRuleTags.append(keep)
            }
            board.smartRuleTags.removeAll { $0.id == remove.id }
        }

        // If remove had a parent, keep that hierarchy for keep (if keep has no parent)
        if let removeParent = remove.parentTag, keep.parentTag == nil {
            keep.parentTag = removeParent
        }

        modelContext.delete(remove)
        try? modelContext.save()
    }

    // MARK: - Hierarchy Detection

    /// Detect potential parent-child relationships among tags
    func findHierarchySuggestions(from tags: [Tag]) -> [TagHierarchySuggestion] {
        var suggestions: [TagHierarchySuggestion] = []

        for i in 0..<tags.count {
            for j in 0..<tags.count {
                guard i != j else { continue }
                let potentialParent = tags[i]
                let potentialChild = tags[j]

                // Skip if already in a hierarchy
                if potentialChild.parentTag != nil { continue }

                // Check if child name contains/starts with parent name (e.g., "SwiftUI" contains "Swift")
                if let reason = checkHierarchyRelationship(parent: potentialParent, child: potentialChild) {
                    suggestions.append(TagHierarchySuggestion(
                        parentTag: potentialParent,
                        childTag: potentialChild,
                        reason: reason
                    ))
                }
            }
        }

        // Deduplicate: only keep the best parent for each child
        var bestForChild: [UUID: TagHierarchySuggestion] = [:]
        for suggestion in suggestions {
            let childID = suggestion.childTag.id
            if let existing = bestForChild[childID] {
                // Prefer longer parent name (more specific parent)
                if suggestion.parentTag.name.count > existing.parentTag.name.count {
                    bestForChild[childID] = suggestion
                }
            } else {
                bestForChild[childID] = suggestion
            }
        }

        return Array(bestForChild.values).sorted { $0.childTag.name < $1.childTag.name }
    }

    private func checkHierarchyRelationship(parent: Tag, child: Tag) -> String? {
        let parentLower = parent.name.lowercased()
        let childLower = child.name.lowercased()

        // Child name must be longer than parent (child is more specific)
        guard childLower.count > parentLower.count else { return nil }

        // The parent name must not be too short (avoid single-char matches)
        guard parentLower.count >= 3 else { return nil }

        // Child starts with parent name: e.g., "SwiftUI" starts with "Swift"
        if childLower.hasPrefix(parentLower) {
            return "\"\(child.name)\" starts with \"\(parent.name)\""
        }

        // Child contains parent as a word: e.g., "Swift Concurrency" contains "Swift"
        let childWords = childLower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let parentWords = parentLower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }

        if parentWords.count == 1 && childWords.contains(parentLower) && childWords.count > 1 {
            return "\"\(child.name)\" contains \"\(parent.name)\" as a component"
        }

        // Co-occurrence: if parent's items are a superset of child's items (child is more specific)
        if !child.items.isEmpty && !parent.items.isEmpty {
            let childItemIDs = Set(child.items.map(\.id))
            let parentItemIDs = Set(parent.items.map(\.id))
            if childItemIDs.isSubset(of: parentItemIDs) && childItemIDs.count < parentItemIDs.count {
                return "All items tagged \"\(child.name)\" are also tagged \"\(parent.name)\""
            }
        }

        return nil
    }

    /// Apply a hierarchy suggestion
    func applyHierarchy(parent: Tag, child: Tag) {
        child.parentTag = parent
        try? modelContext.save()
    }

    /// Remove a hierarchy relationship
    func removeHierarchy(child: Tag) {
        child.parentTag = nil
        try? modelContext.save()
    }

    // MARK: - Trend Tracking

    /// Update trend data for all tags — call periodically (e.g., on app launch)
    func updateTrends(for tags: [Tag]) {
        let now = Date()
        for tag in tags {
            // Only update if we haven't calculated recently (within 24 hours)
            if let lastCalc = tag.trendCalculatedAt,
               now.timeIntervalSince(lastCalc) < 86400 {
                continue
            }
            tag.previousItemCount = tag.items.count
            tag.trendCalculatedAt = now
        }
        try? modelContext.save()
    }

    // MARK: - Improved Clustering (co-occurrence based)

    /// Compute co-occurrence matrix for tags based on shared items
    nonisolated static func tagCooccurrence(tags: [Tag]) -> [UUID: [UUID: Int]] {
        var matrix: [UUID: [UUID: Int]] = [:]
        for tag in tags {
            let itemIDs = Set(tag.items.map(\.id))
            for otherTag in tags where otherTag.id != tag.id {
                let otherItemIDs = Set(otherTag.items.map(\.id))
                let overlap = itemIDs.intersection(otherItemIDs).count
                if overlap > 0 {
                    matrix[tag.id, default: [:]][otherTag.id] = overlap
                }
            }
        }
        return matrix
    }

}
