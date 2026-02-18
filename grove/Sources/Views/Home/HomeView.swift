import SwiftUI
import SwiftData

// MARK: - HomeView

struct HomeView: View {
    @Binding var selectedItem: Item?
    @Binding var openedItem: Item?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.updatedAt, order: .reverse) private var allItems: [Item]

    @State private var starterService = ConversationStarterService()

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
            await starterService.refresh(items: allItems)
        }
    }

    // MARK: - Dialectics Section

    private var dialecticsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("DIALECTICS")
                .sectionHeaderStyle()

            if starterService.bubbles.isEmpty {
                fallbackBubble
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(starterService.bubbles) { bubble in
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
