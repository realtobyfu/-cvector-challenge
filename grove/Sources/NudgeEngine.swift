import Foundation
import SwiftData

/// Generates nudges on app launch based on item status and age.
/// V1 supports two nudge types: resurface and staleInbox.
@Observable
final class NudgeEngine {
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Generate nudges, called on app launch. Creates new pending nudges
    /// while respecting the 30-day dismissal cooldown per item.
    func generateNudges() {
        generateResurfaceNudge()
        generateStaleInboxNudge()
    }

    // MARK: - Resurface Nudge

    /// Picks a random .active item not updated in 14+ days and creates a
    /// resurface nudge, unless one was dismissed for that item within 30 days.
    private func generateResurfaceNudge() {
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now

        let allItems = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
        let staleActiveItems = allItems.filter {
            $0.status == .active && $0.updatedAt < fourteenDaysAgo
        }
        guard !staleActiveItems.isEmpty else { return }

        // Get all nudges to check for recently dismissed and existing pending
        let allNudges = (try? modelContext.fetch(FetchDescriptor<Nudge>())) ?? []

        let dismissedItemIDs = Set(
            allNudges
                .filter { $0.type == .resurface && $0.status == .dismissed && $0.createdAt > thirtyDaysAgo }
                .compactMap { $0.targetItem?.id }
        )

        let pendingItemIDs = Set(
            allNudges
                .filter { $0.type == .resurface && ($0.status == .pending || $0.status == .shown) }
                .compactMap { $0.targetItem?.id }
        )

        let candidates = staleActiveItems.filter {
            !dismissedItemIDs.contains($0.id) && !pendingItemIDs.contains($0.id)
        }
        guard let chosen = candidates.randomElement() else { return }

        let daysSaved = Calendar.current.dateComponents([.day], from: chosen.createdAt, to: .now).day ?? 0
        let message = "You saved \"\(chosen.title)\" \(daysSaved) days ago. Still relevant?"

        let nudge = Nudge(type: .resurface, message: message, targetItem: chosen)
        modelContext.insert(nudge)
        try? modelContext.save()
    }

    // MARK: - Stale Inbox Nudge

    /// If inbox has 5+ items older than 14 days, creates a stale inbox nudge.
    private func generateStaleInboxNudge() {
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now

        let allItems = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
        let staleInboxItems = allItems.filter {
            $0.status == .inbox && $0.createdAt < fourteenDaysAgo
        }
        guard staleInboxItems.count >= 5 else { return }

        // Check existing nudges
        let allNudges = (try? modelContext.fetch(FetchDescriptor<Nudge>())) ?? []

        // Don't create if there's already a pending/shown stale inbox nudge
        let hasPending = allNudges.contains {
            $0.type == .staleInbox && ($0.status == .pending || $0.status == .shown)
        }
        guard !hasPending else { return }

        // Check 30-day cooldown for dismissed stale inbox nudges
        let recentlyDismissed = allNudges.contains {
            $0.type == .staleInbox && $0.status == .dismissed && $0.createdAt > thirtyDaysAgo
        }
        guard !recentlyDismissed else { return }

        let message = "You have \(staleInboxItems.count) items waiting in your inbox"

        let nudge = Nudge(type: .staleInbox, message: message)
        modelContext.insert(nudge)
        try? modelContext.save()
    }
}
