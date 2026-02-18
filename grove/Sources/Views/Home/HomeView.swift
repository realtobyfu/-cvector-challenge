import SwiftUI
import SwiftData

// MARK: - Prompt Bubble Model

struct PromptBubble: Identifiable {
    let id = UUID()
    let prompt: String
    let label: String
}

// MARK: - HomeView

struct HomeView: View {
    @Binding var selectedItem: Item?
    @Binding var openedItem: Item?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.updatedAt, order: .reverse) private var allItems: [Item]

    /// Static heuristic prompt bubbles — replaced in US-002 with LLM-generated ones.
    @State private var promptBubbles: [PromptBubble] = []

    private var recentItems: [Item] {
        Array(allItems.filter { $0.status == .active || $0.status == .inbox }.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                dialecticsSection
                recentItemsSection
                Spacer(minLength: Spacing.xxxl)
            }
            .padding(.horizontal, LayoutDimensions.contentPaddingH)
            .padding(.top, LayoutDimensions.contentPaddingTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
        .navigationTitle("")
        .task {
            buildHeuristicBubbles()
        }
        .onChange(of: allItems.count) {
            buildHeuristicBubbles()
        }
    }

    // MARK: - Dialectics Section

    private var dialecticsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("DIALECTICS")
                .sectionHeaderStyle()

            if promptBubbles.isEmpty {
                fallbackBubble
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(promptBubbles) { bubble in
                        PromptBubbleView(bubble: bubble) {
                            openConversation(with: bubble.prompt)
                        }
                    }
                }
            }
        }
    }

    private var fallbackBubble: some View {
        Button {
            openConversation(with: "")
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.groveBody)
                    .foregroundStyle(Color.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a conversation")
                        .font(.groveBody)
                        .foregroundStyle(Color.textPrimary)
                    Text("Explore your knowledge through dialectical thinking")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textMuted)
            }
            .padding(Spacing.md)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Items Section

    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("RECENT")
                    .sectionHeaderStyle()
                Spacer()
                CaptureBarView()
                    .frame(maxWidth: 280)
            }

            if recentItems.isEmpty {
                Text("No items yet. Capture something to get started.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentItems) { item in
                        compactItemRow(item)
                        if item.id != recentItems.last?.id {
                            Divider().padding(.leading, Spacing.xl + Spacing.sm)
                        }
                    }
                }
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderPrimary, lineWidth: 1)
                )
            }
        }
    }

    private func compactItemRow(_ item: Item) -> some View {
        Button {
            openedItem = item
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: item.type.iconName)
                    .font(.groveBodySecondary)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.groveBody)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    if let board = item.boards.first {
                        Text(board.title)
                            .font(.groveMeta)
                            .foregroundStyle(Color.textTertiary)
                    } else {
                        Text(item.updatedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.groveMeta)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()

                Text(item.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.groveMeta)
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openConversation(with prompt: String) {
        NotificationCenter.default.post(
            name: .groveStartConversationWithPrompt,
            object: prompt
        )
    }

    // MARK: - Heuristic Bubble Generation

    private func buildHeuristicBubbles() {
        var bubbles: [PromptBubble] = []

        // Stale high-value item (untouched 30+ days with reflections)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        if let stale = allItems.first(where: {
            $0.status == .active &&
            $0.updatedAt < thirtyDaysAgo &&
            !$0.reflections.isEmpty
        }) {
            bubbles.append(PromptBubble(
                prompt: "Let's revisit \"\(stale.title)\" — it's been a while. What do you remember, and has your view changed?",
                label: "REVISIT"
            ))
        }

        // Cluster of recent items in last 7 days
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let recentTags = allItems
            .filter { $0.createdAt > sevenDaysAgo }
            .flatMap { $0.tags.map(\.name) }
        let tagCounts = Dictionary(recentTags.map { ($0, 1) }, uniquingKeysWith: +)
        if let topTag = tagCounts.max(by: { $0.value < $1.value }), topTag.value >= 2 {
            let count = allItems.filter { $0.tags.contains(where: { $0.name == topTag.key }) }.count
            bubbles.append(PromptBubble(
                prompt: "You've saved \(count) things about \"\(topTag.key)\" recently. What's the central tension or open question in all this?",
                label: "EXPLORE"
            ))
        }

        // Contradiction prompt if any .contradicts connections exist
        let hasContradiction = allItems.contains { item in
            item.outgoingConnections.contains { $0.type == .contradicts }
        }
        if hasContradiction {
            bubbles.append(PromptBubble(
                prompt: "You have items that contradict each other. Want to work through the tension and find a synthesis?",
                label: "RESOLVE"
            ))
        }

        // General fallback when knowledge base exists but nothing specific triggered
        if bubbles.isEmpty && !allItems.isEmpty {
            bubbles.append(PromptBubble(
                prompt: "What idea from your knowledge base has been sitting unresolved the longest?",
                label: "REFLECT"
            ))
        }

        // Cap at 3
        promptBubbles = Array(bubbles.prefix(3))
    }
}

// MARK: - Prompt Bubble View

struct PromptBubbleView: View {
    let bubble: PromptBubble
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(bubble.label)
                        .font(.groveBadge)
                        .tracking(0.8)
                        .foregroundStyle(Color.textMuted)

                    Text(bubble.prompt)
                        .font(.groveBody)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isHovered ? Color.textSecondary : Color.textMuted)
                    .animation(.easeOut(duration: 0.15), value: isHovered)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.bgCard.opacity(0.85) : Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.borderInput : Color.borderPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Section Header Style

// (HomeSectionHeader kept for backward compat — referenced nowhere else currently)
struct HomeSectionHeader: View {
    let title: String
    let count: Int
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 12)

                Text(title)
                    .sectionHeaderStyle()

                Text("\(count)")
                    .font(.groveBadge)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentBadge)
                    .foregroundStyle(Color.textPrimary)
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
