import SwiftUI
import SwiftData

struct DialecticalChatPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Binding var selectedConversation: Conversation?
    @Binding var isVisible: Bool
    var onNavigateToItem: ((Item) -> Void)?

    @State private var dialecticsService = DialecticsService()
    @State private var inputText = ""
    @State private var showConversationList = false
    @State private var connectionMessage: ChatMessage?
    @State private var connectionSourceIdx = 0
    @State private var connectionTargetIdx = 1
    @State private var connectionType: ConnectionType = .related

    private var activeConversation: Conversation? {
        selectedConversation
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            if let conversation = activeConversation {
                chatView(for: conversation)
            } else {
                emptyState
            }
        }
        .frame(width: 380)
        .background(Color.bgInspector)
        .sheet(item: $connectionMessage) { message in
            connectionSheet(for: message)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Spacing.sm) {
            Text("DIALECTICAL CHAT")
                .font(.groveSectionHeader)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Color.textMuted)

            Spacer()

            if let conversation = activeConversation {
                Text(conversation.title)
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)

                Button {
                    conversation.isArchived = true
                    selectedConversation = nil
                    try? modelContext.save()
                } label: {
                    Image(systemName: "archivebox")
                        .font(.groveBody)
                        .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
                .help("Archive conversation")
            }

            Button {
                showConversationList.toggle()
            } label: {
                Image(systemName: "list.bullet")
                    .font(.groveBody)
                    .foregroundStyle(Color.textMuted)
            }
            .buttonStyle(.plain)
            .help("All conversations")
            .popover(isPresented: $showConversationList) {
                conversationListPopover
            }

            Button {
                startNewConversation()
            } label: {
                Image(systemName: "plus")
                    .font(.groveBody)
                    .foregroundStyle(Color.textMuted)
            }
            .buttonStyle(.plain)
            .help("New conversation")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Chat View

    private func chatView(for conversation: Conversation) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(conversation.visibleMessages) { message in
                            messageBubble(message, conversation: conversation)
                                .id(message.id)
                        }

                        if dialecticsService.isGenerating {
                            thinkingIndicator
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }
                .onChange(of: conversation.messages.count) {
                    if let lastID = conversation.visibleMessages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
            inputArea(for: conversation)
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage, conversation: Conversation) -> some View {
        if message.role == .user {
            userBubble(message)
        } else if message.role == .assistant {
            assistantBubble(message, conversation: conversation)
        }
    }

    private func userBubble(_ message: ChatMessage) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(message.content)
                .font(.groveBody)
                .foregroundStyle(Color.textInverse)
                .padding(Spacing.md)
                .background(Color.accentSelection)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
        }
    }

    private func assistantBubble(_ message: ChatMessage, conversation: Conversation) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                wikiLinkText(message.content)
                    .font(.groveBody)
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)

                // Action buttons
                assistantActions(message: message, conversation: conversation)
            }
            .padding(Spacing.md)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.accentSelection)
                    .frame(width: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 1))
            }

            Spacer(minLength: 40)
        }
    }

    // MARK: - Assistant Actions

    private func assistantActions(message: ChatMessage, conversation: Conversation) -> some View {
        HStack(spacing: Spacing.sm) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.groveBadge)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.textMuted)

            if !message.referencedItemIDs.isEmpty {
                Button {
                    saveReflectionFromMessage(message, conversation: conversation)
                } label: {
                    Label("Save as Reflection", systemImage: "text.badge.plus")
                        .font(.groveBadge)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.textMuted)
            }

            if message.referencedItemIDs.count >= 2 {
                Button {
                    connectionMessage = message
                } label: {
                    Label("Create Connection", systemImage: "link.badge.plus")
                        .font(.groveBadge)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.textMuted)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Wiki-Link Text

    private func wikiLinkText(_ content: String) -> some View {
        let parts = parseWikiLinks(content)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            // Render as plain text with wiki-link markers
            // Full markdown rendering could be added later
            Text(attributedContent(parts))
        }
    }

    private struct TextPart {
        let text: String
        let isWikiLink: Bool
    }

    private func parseWikiLinks(_ content: String) -> [TextPart] {
        var parts: [TextPart] = []
        var remaining = content

        while let openRange = remaining.range(of: "[[") {
            let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
            if !before.isEmpty {
                parts.append(TextPart(text: before, isWikiLink: false))
            }

            remaining = String(remaining[openRange.upperBound...])

            if let closeRange = remaining.range(of: "]]") {
                let linkText = String(remaining[remaining.startIndex..<closeRange.lowerBound])
                parts.append(TextPart(text: linkText, isWikiLink: true))
                remaining = String(remaining[closeRange.upperBound...])
            } else {
                parts.append(TextPart(text: "[[" + remaining, isWikiLink: false))
                remaining = ""
            }
        }

        if !remaining.isEmpty {
            parts.append(TextPart(text: remaining, isWikiLink: false))
        }

        return parts
    }

    private func attributedContent(_ parts: [TextPart]) -> AttributedString {
        var result = AttributedString()
        for part in parts {
            var attr = AttributedString(part.text)
            if part.isWikiLink {
                attr.foregroundColor = .textPrimary
                attr.font = .groveBodyMedium
                attr.backgroundColor = Color.accentBadge
            }
            result.append(attr)
        }
        return result
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Thinking")
                    .font(.groveMeta)
                    .foregroundStyle(Color.textMuted)
                ProgressView()
                    .controlSize(.mini)
            }
            .padding(Spacing.sm)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
        }
    }

    // MARK: - Input Area

    private func inputArea(for conversation: Conversation) -> some View {
        VStack(spacing: Spacing.sm) {
            // Seed item pills
            if !conversation.seedItemIDs.isEmpty {
                seedItemPills(for: conversation)
            }

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Ask, challenge, or reflect...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.groveBody)
                    .lineLimit(1...5)
                    .padding(Spacing.sm)
                    .background(Color.bgInput)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.borderInput, lineWidth: 1)
                    )
                    .onSubmit {
                        sendMessage(to: conversation)
                    }

                Button {
                    sendMessage(to: conversation)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.textMuted : Color.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || dialecticsService.isGenerating)
            }
        }
        .padding(Spacing.md)
    }

    private func seedItemPills(for conversation: Conversation) -> some View {
        let allItems = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
        let seeds = conversation.seedItemIDs.compactMap { id in
            allItems.first(where: { $0.id == id })
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                Text("Context:")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textMuted)
                ForEach(seeds, id: \.id) { item in
                    Button {
                        onNavigateToItem?(item)
                    } label: {
                        Text(item.title)
                            .font(.groveBadge)
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentBadge)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
            Text("Dialectical Chat")
                .font(.groveItemTitle)
                .foregroundStyle(Color.textPrimary)
            Text("Start a conversation to explore your ideas through Socratic questioning and dialectical reasoning.")
                .font(.groveBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                startNewConversation()
            } label: {
                Label("New Conversation", systemImage: "plus")
                    .font(.groveBodyMedium)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            if !conversations.filter({ !$0.isArchived }).isEmpty {
                Divider().padding(.horizontal, Spacing.xxl)
                Text("Recent")
                    .sectionHeaderStyle()
                ForEach(conversations.filter({ !$0.isArchived }).prefix(3)) { conv in
                    Button {
                        selectedConversation = conv
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conv.title)
                                    .font(.groveBody)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.groveMeta)
                                    .foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.groveBadge)
                                .foregroundStyle(Color.textMuted)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }

    // MARK: - Conversation List Popover

    private var conversationListPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONVERSATIONS")
                .sectionHeaderStyle()
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)

            Divider()

            if conversations.filter({ !$0.isArchived }).isEmpty {
                Text("No conversations yet.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding(Spacing.md)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(conversations.filter({ !$0.isArchived })) { conv in
                            Button {
                                selectedConversation = conv
                                showConversationList = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(conv.title)
                                            .font(.groveBody)
                                            .foregroundStyle(Color.textPrimary)
                                            .lineLimit(1)
                                        HStack(spacing: 4) {
                                            Text(conv.trigger.rawValue)
                                                .font(.groveBadge)
                                                .foregroundStyle(Color.textTertiary)
                                            Text(conv.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.groveMeta)
                                                .foregroundStyle(Color.textTertiary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(conv.visibleMessages.count) msgs")
                                        .font(.groveBadge)
                                        .foregroundStyle(Color.textMuted)
                                }
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, Spacing.md)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 300)
    }

    // MARK: - Actions

    private func startNewConversation() {
        let conversation = dialecticsService.startConversation(
            trigger: .userInitiated,
            seedItems: [],
            board: nil,
            context: modelContext
        )
        selectedConversation = conversation
    }

    private func sendMessage(to conversation: Conversation) {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""

        Task {
            _ = await dialecticsService.sendMessage(
                userText: text,
                conversation: conversation,
                context: modelContext
            )
        }
    }

    private func saveReflectionFromMessage(_ message: ChatMessage, conversation: Conversation) {
        guard let firstID = message.referencedItemIDs.first else { return }
        let allItems = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
        guard let item = allItems.first(where: { $0.id == firstID }) else { return }

        _ = dialecticsService.saveAsReflection(
            content: message.content,
            itemTitle: item.title,
            blockType: .keyInsight,
            conversation: conversation,
            context: modelContext
        )
    }

    // MARK: - Connection Sheet

    private func connectionSheet(for message: ChatMessage) -> some View {
        let allItems = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
        let referenced = message.referencedItemIDs.compactMap { id in
            allItems.first(where: { $0.id == id })
        }

        return VStack(spacing: Spacing.lg) {
            Text("Create Connection")
                .font(.groveItemTitle)

            if referenced.count >= 2 {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("From:")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textMuted)
                    Text(referenced[0].title)
                        .font(.groveBody)

                    Text("To:")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textMuted)
                    Text(referenced.count > 1 ? referenced[1].title : "")
                        .font(.groveBody)

                    Picker("Type", selection: $connectionType) {
                        ForEach(ConnectionType.allCases, id: \.self) { type in
                            Text(type.displayLabel).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack {
                    Button("Cancel") {
                        connectionMessage = nil
                    }
                    .buttonStyle(.bordered)

                    Button("Create") {
                        _ = dialecticsService.createConnection(
                            sourceTitle: referenced[0].title,
                            targetTitle: referenced[1].title,
                            type: connectionType,
                            context: modelContext
                        )
                        connectionMessage = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Need at least 2 referenced items to create a connection.")
                    .font(.groveBody)
                    .foregroundStyle(Color.textSecondary)

                Button("Close") {
                    connectionMessage = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 350)
    }
}
