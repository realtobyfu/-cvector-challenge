import Foundation
import SwiftData

/// Response from LLM for learning path generation.
private struct LearningPathResponse: Decodable {
    let steps: [LearningPathStepResponse]
}

private struct LearningPathStepResponse: Decodable {
    let item_title: String
    let reason: String
    let step_number: Int
}

/// Protocol for testability.
@MainActor
protocol LearningPathServiceProtocol {
    func generatePath(items: [Item], topic: String, board: Board?, in context: ModelContext) async -> LearningPath?
}

/// Service that generates ordered learning paths from items using LLM.
/// Falls back to heuristic ordering when AI is unavailable.
@MainActor
@Observable
final class LearningPathService: LearningPathServiceProtocol {
    private let provider: LLMProvider
    var isGenerating = false
    var progress: String = ""

    init(provider: LLMProvider = LLMServiceConfig.makeProvider()) {
        self.provider = provider
    }

    /// Generate a learning path from the given items.
    func generatePath(items: [Item], topic: String, board: Board?, in context: ModelContext) async -> LearningPath? {
        guard items.count >= 2 else { return nil }

        isGenerating = true
        progress = "Analyzing items..."

        let orderedSteps: [(title: String, reason: String)]

        if LLMServiceConfig.isConfigured {
            orderedSteps = await generateLLMPath(items: items, topic: topic)
        } else {
            orderedSteps = generateLocalPath(items: items)
        }

        guard !orderedSteps.isEmpty else {
            isGenerating = false
            progress = ""
            return nil
        }

        progress = "Creating learning path..."

        let path = LearningPath(title: "Learning Path: \(topic)", topic: topic, board: board)
        context.insert(path)

        // Create steps, resolving titles to items
        for (index, stepInfo) in orderedSteps.enumerated() {
            let matchedItem = items.first { $0.title.localizedCaseInsensitiveCompare(stepInfo.title) == .orderedSame }
                ?? items.first { $0.title.localizedCaseInsensitiveContains(stepInfo.title) }
                ?? items.first { stepInfo.title.localizedCaseInsensitiveContains($0.title) }

            let step = LearningPathStep(
                item: matchedItem,
                reason: stepInfo.reason,
                position: index
            )

            // Auto-set progress based on item state
            if let item = matchedItem {
                if !item.reflections.isEmpty {
                    step.progress = .reflected
                } else if item.status != .inbox {
                    step.progress = .read
                }
            }

            context.insert(step)
            path.steps.append(step)
        }

        // Final synthesis step
        let synthesisStep = LearningPathStep(
            item: nil,
            reason: "Consolidate your learning by writing a synthesis note that connects the key themes across all items.",
            position: orderedSteps.count,
            isSynthesisStep: true
        )
        context.insert(synthesisStep)
        path.steps.append(synthesisStep)

        try? context.save()

        isGenerating = false
        progress = ""
        return path
    }

    // MARK: - LLM Path Generation

    private func generateLLMPath(items: [Item], topic: String) async -> [(title: String, reason: String)] {
        progress = "Preparing context for AI..."

        let systemPrompt = """
        You are a learning path curator. The user has collected items (articles, notes, videos, lectures) \
        on a topic. Create an ordered learning path that sequences these items for optimal learning.

        Consider:
        - Start with foundational/introductory items
        - Build complexity gradually
        - Group related sub-topics together
        - Place items with more reflections later (they represent deeper engagement)
        - Items with higher engagement scores indicate more important material

        Return JSON with a "steps" array. Each step has:
        - "item_title": exact title of the item
        - "reason": 1-sentence explanation of why this item belongs at this position
        - "step_number": position in the sequence (1-based)

        Only include items from the provided list. Include ALL items.
        Only output valid JSON, no markdown fences or extra text.
        """

        var itemDescriptions: [String] = []
        for item in items {
            var desc = "Title: \(item.title)\nType: \(item.type.rawValue)"
            let tags = item.tags.map(\.name).joined(separator: ", ")
            if !tags.isEmpty { desc += "\nTags: \(tags)" }
            desc += "\nDepth score: \(item.depthScore)"
            desc += "\nReflections: \(item.reflections.count)"
            desc += "\nConnections: \(item.outgoingConnections.count + item.incomingConnections.count)"
            if let summary = item.metadata["summary"], !summary.isEmpty {
                desc += "\nSummary: \(summary)"
            }
            if let content = item.content {
                desc += "\nContent excerpt: \(String(content.prefix(300)))"
            }
            if !item.reflections.isEmpty {
                let reflectionSummary = item.reflections.sorted { $0.position < $1.position }.prefix(3).map {
                    "[\($0.blockType.displayName)] \(String($0.content.prefix(100)))"
                }.joined(separator: "; ")
                desc += "\nReflection notes: \(reflectionSummary)"
            }
            itemDescriptions.append(desc)
        }

        let userPrompt = """
        Create a learning path for the topic "\(topic)" from these \(items.count) items:

        \(itemDescriptions.enumerated().map { "--- Item \($0.offset + 1) ---\n\($0.element)" }.joined(separator: "\n\n"))

        Return a JSON object with a "steps" array ordering ALL items for optimal learning progression.
        """

        progress = "Generating learning path..."

        guard let result = await provider.complete(system: systemPrompt, user: userPrompt, service: "learning_path") else {
            return generateLocalPath(items: items)
        }

        guard let response = LLMJSONParser.decode(LearningPathResponse.self, from: result.content) else {
            return generateLocalPath(items: items)
        }

        let sorted = response.steps.sorted { $0.step_number < $1.step_number }
        return sorted.map { (title: $0.item_title, reason: $0.reason) }
    }

    // MARK: - Local Path Generation (Heuristic Fallback)

    private func generateLocalPath(items: [Item]) -> [(title: String, reason: String)] {
        progress = "Creating path from item metadata..."

        // Sort by: depth score ascending (less engaged first), then by creation date
        let sorted = items.sorted { a, b in
            if a.depthScore != b.depthScore {
                return a.depthScore < b.depthScore
            }
            return a.createdAt < b.createdAt
        }

        return sorted.map { item in
            let reason: String
            if item.depthScore == 0 {
                reason = "Start here — this item hasn't been explored yet."
            } else if item.reflections.isEmpty {
                reason = "Read through this item and add your reflections."
            } else {
                reason = "You've reflected on this — revisit to deepen your understanding."
            }
            return (title: item.title, reason: reason)
        }
    }
}

// MARK: - String Helpers

private extension String {
    func localizedCaseInsensitiveContains(_ other: String) -> Bool {
        range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
