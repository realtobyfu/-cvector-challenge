import SwiftUI
import SwiftData

// MARK: - AttributedStringEditorView

/// A macOS 26+ text editor that uses SwiftUI's native TextEditor(text:selection:)
/// with AttributedString for rich markdown editing with selection-aware formatting.
@available(macOS 26, *)
struct AttributedStringEditorView: View {
    @Binding var markdownText: String
    var sourceItem: Item?
    var proseMode: Bool = false
    var minHeight: CGFloat = 80

    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [Item]

    @State private var attributedText: AttributedString = AttributedString()
    @State private var selection = AttributedTextSelection()
    @State private var isUpdatingFromMarkdown = false
    @State private var isUpdatingFromAttributed = false
    @State private var serializationTask: Task<Void, Never>?

    // Wiki-link autocomplete
    @State private var showWikiPopover = false
    @State private var wikiSearchText = ""

    private let converter = MarkdownAttributedStringConverter()
    private var formatting: GroveFormattingDefinition {
        GroveFormattingDefinition(fontSize: proseMode ? 18 : 15)
    }

    private var wikiSearchResults: [Item] {
        allItems.filter { candidate in
            if let sourceItem, candidate.id == sourceItem.id { return false }
            if wikiSearchText.isEmpty { return true }
            return candidate.title.localizedCaseInsensitiveContains(wikiSearchText)
        }.prefix(10).map { $0 }
    }

    var body: some View {
        if proseMode {
            proseLayout
        } else {
            standardLayout
        }
    }

    // MARK: - Standard Layout

    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            formattingToolbar
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.borderInput, lineWidth: 1)
                )
                .padding(.bottom, 4)

            TextEditor(text: $attributedText, selection: $selection)
                .font(formatting.bodyFont)
                .frame(minHeight: minHeight)
                .background(Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.borderInput, lineWidth: 1)
                )

            if showWikiPopover {
                wikiLinkDropdown
            }
        }
        .onAppear { loadAttributedText() }
        .onChange(of: markdownText) { _, newValue in
            guard !isUpdatingFromAttributed else { return }
            isUpdatingFromMarkdown = true
            attributedText = converter.attributedString(from: newValue)
            formatting.applyPresentation(to: &attributedText)
            isUpdatingFromMarkdown = false
        }
        .onChange(of: attributedText) { _, _ in
            guard !isUpdatingFromMarkdown else { return }
            scheduleSerializeToMarkdown()
            detectWikiLink()
        }
    }

    // MARK: - Prose Layout

    private var proseLayout: some View {
        VStack(spacing: 0) {
            TextEditor(text: $attributedText, selection: $selection)
                .font(formatting.bodyFont)
                .lineSpacing(8)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .frame(minHeight: minHeight)

            if showWikiPopover {
                wikiLinkDropdown
                    .padding(.horizontal, 40)
            }

            proseToolbar
        }
        .onAppear { loadAttributedText() }
        .onChange(of: markdownText) { _, newValue in
            guard !isUpdatingFromAttributed else { return }
            isUpdatingFromMarkdown = true
            attributedText = converter.attributedString(from: newValue)
            formatting.applyPresentation(to: &attributedText)
            isUpdatingFromMarkdown = false
        }
        .onChange(of: attributedText) { _, _ in
            guard !isUpdatingFromMarkdown else { return }
            scheduleSerializeToMarkdown()
            detectWikiLink()
        }
    }

    // MARK: - Load

    private func loadAttributedText() {
        attributedText = converter.attributedString(from: markdownText)
        formatting.applyPresentation(to: &attributedText)
    }

    // MARK: - Serialize to Markdown (debounced)

    private func scheduleSerializeToMarkdown() {
        serializationTask?.cancel()
        serializationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            isUpdatingFromAttributed = true
            markdownText = converter.markdown(from: attributedText)
            isUpdatingFromAttributed = false
        }
    }

    // MARK: - Formatting Toolbar

    private var formattingToolbar: some View {
        HStack(spacing: 2) {
            toolbarButton("Bold", icon: "bold", shortcut: "B") { toggleBold() }
            toolbarButton("Italic", icon: "italic", shortcut: "I") { toggleItalic() }
            toolbarButton("Code", icon: "chevron.left.forwardslash.chevron.right", shortcut: "E") { toggleInlineCode() }
            toolbarButton("Strikethrough", icon: "strikethrough", shortcut: nil) { toggleStrikethrough() }

            Divider().frame(height: 16).padding(.horizontal, 4)

            toolbarButton("Heading", icon: "number", shortcut: nil) { toggleHeading() }
            toolbarButton("Quote", icon: "text.quote", shortcut: nil) { toggleBlockQuote() }
            toolbarButton("List", icon: "list.bullet", shortcut: nil) { toggleListItem() }

            Divider().frame(height: 16).padding(.horizontal, 4)

            toolbarButton("Link", icon: "link", shortcut: "K") { insertLink() }
            toolbarButton("Wiki Link", icon: "link.badge.plus", shortcut: nil) { insertWikiLinkSyntax() }

            Spacer()
        }
    }

    private var proseToolbar: some View {
        HStack(spacing: 16) {
            toolbarButton("Bold", icon: "bold", shortcut: "B") { toggleBold() }
            toolbarButton("Italic", icon: "italic", shortcut: "I") { toggleItalic() }
            toolbarButton("Code", icon: "chevron.left.forwardslash.chevron.right", shortcut: "E") { toggleInlineCode() }
            toolbarButton("Link", icon: "link", shortcut: "K") { insertLink() }
            toolbarButton("Wiki Link", icon: "link.badge.plus", shortcut: nil) { insertWikiLinkSyntax() }
            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 8)
    }

    private func toolbarButton(_ label: String, icon: String, shortcut: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.textSecondary)
        .help(shortcut != nil ? "\(label) (\u{2318}\(shortcut!))" : label)
    }

    // MARK: - Formatting Actions

    private func toggleBold() {
        insertMarkdownSyntax(prefix: "**", suffix: "**")
    }

    private func toggleItalic() {
        insertMarkdownSyntax(prefix: "*", suffix: "*")
    }

    private func toggleInlineCode() {
        insertMarkdownSyntax(prefix: "`", suffix: "`")
    }

    private func toggleStrikethrough() {
        insertMarkdownSyntax(prefix: "~~", suffix: "~~")
    }

    private func insertMarkdownSyntax(prefix: String, suffix: String) {
        isUpdatingFromMarkdown = true
        markdownText += prefix + suffix
        attributedText = converter.attributedString(from: markdownText)
        formatting.applyPresentation(to: &attributedText)
        isUpdatingFromMarkdown = false
    }

    private func toggleHeading() {
        markdownText += "\n# "
        reloadFromMarkdown()
    }

    private func toggleBlockQuote() {
        markdownText += "\n> "
        reloadFromMarkdown()
    }

    private func toggleListItem() {
        markdownText += "\n- "
        reloadFromMarkdown()
    }

    private func insertLink() {
        markdownText += "[](url)"
        reloadFromMarkdown()
    }

    private func insertWikiLinkSyntax() {
        markdownText += "[[]]"
        reloadFromMarkdown()
    }

    private func reloadFromMarkdown() {
        isUpdatingFromMarkdown = true
        attributedText = converter.attributedString(from: markdownText)
        formatting.applyPresentation(to: &attributedText)
        isUpdatingFromMarkdown = false
    }

    // MARK: - Wiki Link Detection

    private func detectWikiLink() {
        let text = String(attributedText.characters)
        guard let openRange = text.range(of: "[[", options: .backwards) else {
            if showWikiPopover {
                showWikiPopover = false
                wikiSearchText = ""
            }
            return
        }

        let afterBrackets = text[openRange.upperBound...]
        if afterBrackets.contains("]]") {
            if showWikiPopover {
                showWikiPopover = false
                wikiSearchText = ""
            }
            return
        }

        wikiSearchText = String(afterBrackets)
        showWikiPopover = true
    }

    // MARK: - Wiki Link Dropdown

    private var wikiLinkDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "link")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textSecondary)
                Text("Link to item")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Button {
                    showWikiPopover = false
                    wikiSearchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.groveBadge)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)

            Divider()

            if wikiSearchResults.isEmpty {
                Text("No matching items")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textTertiary)
                    .padding(8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(wikiSearchResults) { candidate in
                            Button {
                                insertWikiLink(for: candidate)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: candidate.type.iconName)
                                        .font(.groveBadge)
                                        .foregroundStyle(Color.textSecondary)
                                        .frame(width: 14)
                                    Text(candidate.title)
                                        .font(.groveBodySmall)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.borderPrimary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func insertWikiLink(for target: Item) {
        if let range = markdownText.range(of: "[[", options: .backwards) {
            let before = markdownText[markdownText.startIndex..<range.lowerBound]
            markdownText = before + "[[" + target.title + "]]"
        }

        // Auto-create connection
        if let sourceItem {
            let viewModel = ItemViewModel(modelContext: modelContext)
            let alreadyConnected = sourceItem.outgoingConnections.contains { $0.targetItem?.id == target.id }
                || sourceItem.incomingConnections.contains { $0.sourceItem?.id == target.id }
            if !alreadyConnected {
                _ = viewModel.createConnection(source: sourceItem, target: target, type: .related)
            }
        }

        showWikiPopover = false
        wikiSearchText = ""
        reloadFromMarkdown()
    }
}
