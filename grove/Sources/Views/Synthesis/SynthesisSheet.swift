import SwiftUI
import SwiftData

/// Sheet for generating and previewing an AI synthesis note.
struct SynthesisSheet: View {
    let items: [Item]
    let scopeTitle: String
    let board: Board?
    let onCreated: (Item) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var synthesisService: SynthesisService?
    @State private var result: SynthesisResult?
    @State private var draftTitle: String = ""
    @State private var draftContent: String = ""
    @State private var isEditing = false
    @State private var hasGenerated = false

    private var itemCountWarning: Bool {
        items.count > 15
    }

    // MARK: - DESIGN.md Color Tokens

    private var cardBackground: Color {
        Color(hex: colorScheme == .dark ? "1A1A1A" : "FFFFFF")
    }
    private var borderColor: Color {
        Color(hex: colorScheme == .dark ? "222222" : "EBEBEB")
    }
    private var textPrimary: Color {
        Color(hex: colorScheme == .dark ? "E8E8E8" : "1A1A1A")
    }
    private var textSecondary: Color {
        Color(hex: colorScheme == .dark ? "888888" : "777777")
    }
    private var textMuted: Color {
        Color(hex: colorScheme == .dark ? "444444" : "BBBBBB")
    }
    private var badgeBackground: Color {
        Color(hex: colorScheme == .dark ? "2A2A2A" : "E8E8E8")
    }
    private var backgroundPrimary: Color {
        Color(hex: colorScheme == .dark ? "111111" : "FAFAFA")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let service = synthesisService, service.isGenerating {
                generatingView(service: service)
            } else if hasGenerated, result != nil {
                previewView
            } else if let service = synthesisService, let error = service.lastError {
                errorView(error: error)
            } else {
                scopeOverview
            }

            Divider()
            footer
        }
        .frame(width: 600, height: 550)
        .background(backgroundPrimary)
        .onAppear {
            synthesisService = SynthesisService(modelContext: modelContext)
            draftTitle = "Synthesis: \(scopeTitle)"
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("SYNTHESIS")
                .font(.custom("IBMPlexMono", size: 10))
                .fontWeight(.medium)
                .tracking(1.2)
                .foregroundStyle(textMuted)

            Spacer()

            if let result, hasGenerated {
                HStack(spacing: 4) {
                    Image(systemName: result.isLLMGenerated ? "sparkles" : "cpu")
                        .font(.system(size: 9))
                    Text(result.isLLMGenerated ? "AI Draft" : "Local")
                        .font(.custom("IBMPlexMono", size: 10))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeBackground)
                .clipShape(Capsule())
            }

            Text("\(items.count) items")
                .font(.custom("IBMPlexMono", size: 10))
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeBackground)
                .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - Scope Overview (before generation)

    private var scopeOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SCOPE")
                        .font(.custom("IBMPlexMono", size: 10))
                        .fontWeight(.medium)
                        .tracking(1.2)
                        .foregroundStyle(textMuted)

                    HStack {
                        Text(scopeTitle)
                            .font(.custom("IBMPlexSans-Regular", size: 13))
                            .fontWeight(.medium)
                            .foregroundStyle(textPrimary)
                        Spacer()
                    }
                }

                if itemCountWarning {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                        Text("Large scope (\(items.count) items). Synthesis works best with 3-15 items.")
                            .font(.custom("IBMPlexSans-Regular", size: 11))
                    }
                    .foregroundStyle(textSecondary)
                    .padding(10)
                    .background(badgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Text("ITEMS")
                    .font(.custom("IBMPlexMono", size: 10))
                    .fontWeight(.medium)
                    .tracking(1.2)
                    .foregroundStyle(textMuted)

                ForEach(items.prefix(20)) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.type.iconName)
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.custom("IBMPlexSans-Regular", size: 12))
                                .foregroundStyle(textPrimary)
                                .lineLimit(1)
                            if !item.tags.isEmpty {
                                Text(item.tags.prefix(3).map(\.name).joined(separator: ", "))
                                    .font(.custom("IBMPlexMono", size: 10))
                                    .foregroundStyle(textMuted)
                            }
                        }
                        Spacer()
                        if !item.reflections.isEmpty {
                            Text("\(item.reflections.count) reflections")
                                .font(.custom("IBMPlexMono", size: 10))
                                .foregroundStyle(textMuted)
                        }
                    }
                }

                if items.count > 20 {
                    Text("...and \(items.count - 20) more")
                        .font(.custom("IBMPlexSans-Regular", size: 11))
                        .foregroundStyle(textMuted)
                }

                if LLMServiceConfig.isConfigured {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("AI synthesis enabled — will use your reflections and wiki-links")
                            .font(.custom("IBMPlexSans-Regular", size: 11))
                    }
                    .foregroundStyle(textSecondary)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                        Text("Local synthesis — configure AI in Settings for richer results")
                            .font(.custom("IBMPlexSans-Regular", size: 11))
                    }
                    .foregroundStyle(textMuted)
                }
            }
            .padding()
        }
    }

    // MARK: - Generating

    private func generatingView(service: SynthesisService) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text(service.progress)
                .font(.custom("IBMPlexSans-Regular", size: 12))
                .foregroundStyle(textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(textSecondary)
            Text("Synthesis Failed")
                .font(.custom("IBMPlexSans-Regular", size: 13))
                .fontWeight(.medium)
                .foregroundStyle(textPrimary)
            Text(error)
                .font(.custom("IBMPlexSans-Regular", size: 12))
                .foregroundStyle(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                startGeneration()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(Color(hex: "1A1A1A"))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview (after generation)

    private var previewView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title field
            HStack(spacing: 8) {
                TextField("Synthesis title", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.custom("Newsreader", size: 18).weight(.medium))
                    .foregroundStyle(textPrimary)
                Spacer()
                Button {
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Preview" : "Edit")
                        .font(.custom("IBMPlexMono", size: 10))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeBackground)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            ScrollView {
                if isEditing {
                    TextEditor(text: $draftContent)
                        .font(.custom("IBMPlexMono", size: 12))
                        .scrollContentBackground(.hidden)
                        .padding()
                        .frame(minHeight: 300)
                } else {
                    MarkdownTextView(markdown: draftContent)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .foregroundStyle(textSecondary)

            Spacer()

            if hasGenerated && result != nil {
                Button("Regenerate") {
                    startGeneration()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button("Save Note") {
                    saveNote()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(Color(hex: "1A1A1A"))
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Generate Synthesis") {
                    startGeneration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(Color(hex: "1A1A1A"))
                .keyboardShortcut(.defaultAction)
                .disabled(synthesisService?.isGenerating == true)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func startGeneration() {
        guard let service = synthesisService else { return }
        hasGenerated = false
        result = nil

        Task {
            if let generated = await service.generateSynthesis(items: items, scopeTitle: scopeTitle) {
                result = generated
                draftContent = generated.markdownContent
                hasGenerated = true
            }
        }
    }

    private func saveNote() {
        guard let result, let service = synthesisService else { return }
        let title = draftTitle.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Synthesis: \(scopeTitle)"
            : draftTitle

        // If user edited the content, use the edited version and mark as edited
        var finalResult = result
        if draftContent != result.markdownContent {
            finalResult = SynthesisResult(
                markdownContent: draftContent,
                sourceItemIDs: result.sourceItemIDs,
                isLLMGenerated: result.isLLMGenerated
            )
        }

        let item = service.createSynthesisItem(from: finalResult, title: title, inBoard: board)

        // If user edited content before saving, mark as edited
        if draftContent != result.markdownContent {
            item.metadata["isAIEdited"] = "true"
        }

        onCreated(item)
        dismiss()
    }
}
