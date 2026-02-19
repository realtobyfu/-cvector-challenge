import SwiftUI
import SwiftData

// MARK: - HomeView

struct HomeView: View {
    @Binding var selectedItem: Item?
    @Binding var openedItem: Item?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.updatedAt, order: .reverse) private var allItems: [Item]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var allConversations: [Conversation]

    @State private var starterService = ConversationStarterService()
    @State private var isInboxCollapsed = false
    @State private var isDialecticCollapsed = false
    @State private var isSuggestionsCollapsed = false
    @State private var isItemsCollapsed = false
    @State private var isConversationsCollapsed = false

    private var inboxCount: Int {
        allItems.filter { $0.status == .inbox }.count
    }

    private var dialecticBubbles: [PromptBubble] {
        Array(starterService.bubbles.prefix(2))
    }

    private var writingBubbles: [PromptBubble] {
        Array(starterService.bubbles.dropFirst(2).prefix(3))
    }

    private var recentItems: [Item] {
        Array(allItems.filter { $0.status == .active || $0.status == .inbox }.prefix(6))
    }

    private var recentConversations: [Conversation] {
        Array(allConversations.filter { !$0.isArchived }.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CaptureBarView()
                    .padding(.bottom, Spacing.sm)

                inboxSection
                    .padding(.bottom, Spacing.xl)

                dialecticSection
                    .padding(.bottom, Spacing.xl)

                suggestionsSection
                    .padding(.bottom, Spacing.xl)

                recentItemsSection
                    .padding(.bottom, Spacing.xl)

                if !recentConversations.isEmpty {
                    recentConversationsSection
                        .padding(.bottom, Spacing.xl)
                }

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

    // MARK: - Inbox Section

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeader(title: "INBOX", count: inboxCount, isCollapsed: $isInboxCollapsed)
            if !isInboxCollapsed {
                InboxTriageView(selectedItem: $selectedItem, openedItem: $openedItem, isEmbedded: true)
            }
        }
    }

    // MARK: - Dialectic Section

    private var dialecticSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "DIALECTIC",
                count: 1 + dialecticBubbles.count,
                isCollapsed: $isDialecticCollapsed
            )

            if !isDialecticCollapsed {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 250, maximum: 400), spacing: Spacing.md)],
                    spacing: Spacing.md
                ) {
                    SuggestedConversationCard(
                        label: "CHAT",
                        title: "New Conversation",
                        subtitle: "Start an open-ended dialectical session",
                        icon: "bubble.left.and.bubble.right"
                    ) {
                        openConversation(with: "")
                    }

                    ForEach(dialecticBubbles) { bubble in
                        SuggestedConversationCard(
                            label: bubble.label,
                            title: bubble.prompt
                        ) {
                            openDialecticPrompt(bubble.prompt)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "WRITING PROMPTS",
                count: writingBubbles.count,
                isCollapsed: $isSuggestionsCollapsed
            )

            if !isSuggestionsCollapsed {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 250, maximum: 400), spacing: Spacing.md)],
                    spacing: Spacing.md
                ) {
                    ForEach(writingBubbles) { bubble in
                        SuggestedConversationCard(
                            label: bubble.label,
                            title: bubble.prompt
                        ) {
                            openWritingPrompt(bubble.prompt)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Items Section

    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "RECENT ITEMS",
                count: recentItems.count,
                isCollapsed: $isItemsCollapsed
            )

            if !isItemsCollapsed {
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

    // MARK: - Recent Conversations Section

    private var recentConversationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "RECENT CONVERSATIONS",
                count: recentConversations.count,
                isCollapsed: $isConversationsCollapsed
            )

            if !isConversationsCollapsed {
                VStack(spacing: 0) {
                    ForEach(recentConversations) { conversation in
                        conversationRow(conversation)
                        if conversation.id != recentConversations.last?.id {
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

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            NotificationCenter.default.post(
                name: .groveOpenConversation,
                object: conversation
            )
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.groveBodySecondary)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.displayTitle)
                        .font(.groveBody)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    if let last = conversation.visibleMessages.last {
                        Text(last.content)
                            .font(.groveMeta)
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.groveMeta)
                        .foregroundStyle(Color.textMuted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.textMuted)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openWritingPrompt(_ question: String) {
        NotificationCenter.default.post(name: .groveNewNoteWithPrompt, object: question)
    }

    private func openDialecticPrompt(_ question: String) {
        NotificationCenter.default.post(name: .groveStartDialecticWithDisplayPrompt, object: question)
    }

    private func openConversation(with prompt: String, seedItemIDs: [UUID] = []) {
        var userInfo: [String: Any] = [:]
        if !seedItemIDs.isEmpty {
            userInfo["seedItemIDs"] = seedItemIDs
        }
        NotificationCenter.default.post(
            name: .groveStartConversationWithPrompt,
            object: prompt,
            userInfo: userInfo.isEmpty ? nil : userInfo
        )
    }
}

// MARK: - Suggested Conversation Card

struct SuggestedConversationCard: View {
    let label: String
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentSelection)
                    .frame(width: 2)

                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(label.uppercased())
                            .font(.groveBadge)
                            .tracking(0.8)
                            .foregroundStyle(Color.textSecondary)

                        HStack(spacing: Spacing.sm) {
                            if let icon {
                                Image(systemName: icon)
                                    .font(.groveBodySecondary)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Text(title)
                                .font(.groveBody)
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        if let subtitle {
                            Text(subtitle)
                                .font(.groveBodySecondary)
                                .foregroundStyle(Color.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isHovered ? Color.textSecondary : Color.textMuted)
                        .animation(.easeOut(duration: 0.15), value: isHovered)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(isHovered ? Color.bgCard.opacity(0.85) : Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.borderInput : Color.borderPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Prompt Bubble View (kept for backward compat)

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
