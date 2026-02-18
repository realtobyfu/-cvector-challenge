import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedItem: Item?
    @Binding var openedItem: Item?
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [Item]
    @Query(sort: \LearningPath.updatedAt, order: .reverse) private var learningPaths: [LearningPath]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var isInboxCollapsed = false
    @State private var isPathsCollapsed = false
    @State private var isConversationsCollapsed = false
    @State private var openedLearningPath: LearningPath?

    private var inboxCount: Int {
        allItems.filter { $0.status == .inbox }.count
    }

    private var activeConversations: [Conversation] {
        conversations.filter { !$0.isArchived }
    }

    var body: some View {
        if let path = openedLearningPath {
            LearningPathDetailView(learningPath: path, openedItem: $openedItem)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            openedLearningPath = nil
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .help("Back to Home")
                    }
                }
        } else {
            dashboard
        }
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                // Inbox Section
                inboxSection

                // Learning Paths Section
                if !learningPaths.isEmpty {
                    learningPathsSection
                }

                // Conversations Section
                if !activeConversations.isEmpty {
                    conversationsSection
                }

                Spacer(minLength: Spacing.xxxl)
            }
            .padding(.horizontal, LayoutDimensions.contentPaddingH)
            .padding(.top, LayoutDimensions.contentPaddingTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary)
    }

    // MARK: - Inbox Section

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeader(
                title: "Inbox",
                count: inboxCount,
                isCollapsed: $isInboxCollapsed
            )

            if !isInboxCollapsed {
                InboxTriageView(
                    selectedItem: $selectedItem,
                    openedItem: $openedItem,
                    isEmbedded: true
                )
            }
        }
    }

    // MARK: - Learning Paths Section

    private var learningPathsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "Learning Paths",
                count: learningPaths.count,
                isCollapsed: $isPathsCollapsed
            )

            if !isPathsCollapsed {
                ForEach(learningPaths) { path in
                    learningPathCard(path)
                }
            }
        }
    }

    private func learningPathCard(_ path: LearningPath) -> some View {
        let completedCount = path.steps.filter { $0.progress == .reflected && !$0.isSynthesisStep }.count
        let totalSteps = path.steps.filter { !$0.isSynthesisStep }.count
        let progress: Double = totalSteps > 0 ? Double(completedCount) / Double(totalSteps) : 0

        return Button {
            openedLearningPath = path
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(path.title)
                    .font(.groveItemTitle)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: Spacing.md) {
                    Text("\(completedCount)/\(totalSteps) completed")
                        .font(.groveMeta)
                        .foregroundStyle(Color.textSecondary)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.barTrack)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentSelection)
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: 120)
                }

                HStack(spacing: Spacing.md) {
                    if let board = path.board {
                        HStack(spacing: 4) {
                            Image(systemName: board.icon ?? "folder")
                                .font(.groveBadge)
                            Text(board.title)
                                .font(.groveMeta)
                        }
                        .foregroundStyle(Color.textTertiary)
                    }

                    Text(path.createdAt.formatted(.dateTime.month().day()))
                        .font(.groveMeta)
                        .foregroundStyle(Color.textMuted)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conversations Section

    private var conversationsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "Recent Conversations",
                count: activeConversations.count,
                isCollapsed: $isConversationsCollapsed
            )

            if !isConversationsCollapsed {
                ForEach(activeConversations.prefix(5)) { conversation in
                    conversationRow(conversation)
                }
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            NotificationCenter.default.post(name: .groveOpenConversation, object: conversation)
        } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.groveBody)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if let lastMsg = conversation.lastMessage, lastMsg.role != .system {
                        Text(lastMsg.content)
                            .font(.groveBodySecondary)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(conversation.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.groveMeta)
                    .foregroundStyle(Color.textMuted)

                Image(systemName: "chevron.right")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

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
