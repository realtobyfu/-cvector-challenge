import SwiftUI
import SwiftData

// MARK: - NoteWriterOverlayView

/// Full-panel note writer overlay — same aesthetic as the reflection editor panel
/// in ItemReaderView. Appears centered over the detail area with a dimmed backdrop.
struct NoteWriterOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Board.sortOrder) private var boards: [Board]

    @Binding var isPresented: Bool
    var currentBoardID: UUID?
    var prompt: String? = nil
    var editingItem: Item? = nil
    var panelMode: Bool = false
    var onCreated: ((Item) -> Void)?

    @State private var title = ""
    @State private var content = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        if panelMode {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                if let prompt {
                    promptCallout(prompt)
                }
                titleField
                Divider()
                    .padding(.horizontal, 40)
                bodyEditor
                saveBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgPrimary)
            .onAppear {
                if let editingItem {
                    title = editingItem.title
                    content = editingItem.content ?? ""
                }
                isTitleFocused = true
            }
            .onExitCommand {
                dismiss()
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                if let prompt {
                    promptCallout(prompt)
                }
                titleField
                Divider()
                    .padding(.horizontal, 40)
                bodyEditor
                saveBar
            }
            .frame(width: 680, height: 520)
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
            .onAppear {
                isTitleFocused = true
            }
            .onExitCommand {
                dismiss()
            }
        }
    }

    // MARK: - Prompt Callout

    private func promptCallout(_ text: String) -> some View {
        Text(text)
            .font(.groveGhostText)
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgInput)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 40)
            .padding(.bottom, 8)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text(editingItem != nil ? "EDIT" : prompt != nil ? "WRITE" : "NOTE")
                .font(.groveMeta)
                .foregroundStyle(Color.textTertiary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.groveBody)
                    .foregroundStyle(Color.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Title Field

    private var titleField: some View {
        TextField("", text: $title, prompt:
            Text("Title…")
                .foregroundStyle(Color.textMuted)
        )
        .textFieldStyle(.plain)
        .font(.groveItemTitle)
        .foregroundStyle(Color.textPrimary)
        .focused($isTitleFocused)
        .padding(.horizontal, 40)
        .padding(.vertical, 10)
    }

    // MARK: - Body Editor

    private var bodyEditor: some View {
        RichMarkdownEditor(text: $content, sourceItem: nil, minHeight: 200, proseMode: true)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.groveBody)
            .foregroundStyle(Color.textSecondary)

            Button {
                save()
            } label: {
                HStack(spacing: 4) {
                    Text("Save")
                    Text("⌘↩")
                        .font(.groveShortcut)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .font(.groveBodyMedium)
            .foregroundStyle(Color.textPrimary)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                      content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteTitle = trimmedTitle.isEmpty ? "Untitled Note" : trimmedTitle
        let noteContent = trimmedContent.isEmpty ? nil : trimmedContent

        if let editingItem {
            editingItem.title = noteTitle
            editingItem.content = noteContent
            editingItem.updatedAt = .now
            try? modelContext.save()
            onCreated?(editingItem)
            dismiss()
        } else {
            let viewModel = ItemViewModel(modelContext: modelContext)
            let note = viewModel.createNote(title: noteTitle)
            note.content = noteContent

            if let boardID = currentBoardID,
               let board = boards.first(where: { $0.id == boardID }) {
                viewModel.assignToBoard(note, board: board)
            }

            onCreated?(note)
            dismiss()
        }
    }

    private func dismiss() {
        // Resign first responder before animating out so macOS doesn't leave
        // the window in a state where clicks stop reaching underlying views.
        NSApp.keyWindow?.makeFirstResponder(nil)
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}
