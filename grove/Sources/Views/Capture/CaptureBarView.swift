import SwiftUI
import SwiftData

// MARK: - Board Suggestion Banner

/// Non-blocking inline suggestion shown after auto-tagging proposes a new board.
/// Auto-dismisses after 5 seconds. The item is already saved; this is a post-save prompt.
private struct BoardSuggestionBanner: View {
    let boardName: String
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "square.stack")
                .font(.groveMeta)
                .foregroundStyle(Color.textSecondary)

            Text("This doesn't fit your boards. Create \"\(boardName)\"?")
                .font(.groveBodySmall)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button("Create") {
                onAccept()
            }
            .font(.groveBodySmall)
            .foregroundStyle(Color.textPrimary)
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.groveMeta)
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, Spacing.lg)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - CaptureBarView

struct CaptureBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Board.sortOrder) private var boards: [Board]
    @State private var inputText = ""
    @State private var showConfirmation = false
    @FocusState private var isFocused: Bool

    // Board suggestion state
    @State private var pendingSuggestionItemID: UUID? = nil
    @State private var pendingSuggestionBoardName: String = ""
    @State private var showBoardSuggestion = false
    @State private var suggestionDismissTask: Task<Void, Never>? = nil

    /// Currently selected board (passed from ContentView)
    var currentBoardID: UUID?

    private var isURL: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isURL ? "link" : "note.text")
                    .font(.groveMeta)
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 16)

                TextField("", text: $inputText, prompt:
                    Text("Paste a URL or type a note...")
                        .font(.groveGhostText)
                        .foregroundStyle(Color.textMuted)
                )
                .textFieldStyle(.plain)
                .font(.groveBody)
                .foregroundStyle(Color.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    capture()
                }

                if !inputText.isEmpty {
                    Button {
                        capture()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.groveBody)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("⏎")
                    .font(.groveShortcut)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(Color.bgInput)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFocused ? Color.borderPrimary : Color.borderInput, lineWidth: 1)
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .overlay {
                if showConfirmation {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.groveBody)
                        Text("Captured")
                            .font(.groveBodySmall)
                    }
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.bgCard)
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            if showBoardSuggestion {
                BoardSuggestionBanner(
                    boardName: pendingSuggestionBoardName,
                    onAccept: { acceptBoardSuggestion() },
                    onDismiss: { dismissBoardSuggestion() }
                )
                .padding(.top, Spacing.xs)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .groveNewBoardSuggestion)) { notification in
            guard let itemID = notification.userInfo?["itemID"] as? UUID,
                  let boardName = notification.userInfo?["boardName"] as? String,
                  !boardName.isEmpty else { return }

            // Only show suggestion if the item wasn't already assigned to a board (currentBoardID check)
            if currentBoardID != nil { return }

            pendingSuggestionItemID = itemID
            pendingSuggestionBoardName = boardName
            withAnimation(.easeOut(duration: 0.2)) {
                showBoardSuggestion = true
            }
            scheduleAutoDismiss()
        }
    }

    // MARK: - Capture

    private func capture() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let viewModel = ItemViewModel(modelContext: modelContext)
        let item = viewModel.captureItem(input: trimmed)

        // Auto-assign to current board if one is selected
        if let boardID = currentBoardID,
           let board = boards.first(where: { $0.id == boardID }) {
            viewModel.assignToBoard(item, board: board)
        }

        inputText = ""

        // Flash confirmation
        withAnimation(.easeIn(duration: 0.15)) {
            showConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfirmation = false
            }
        }
    }

    // MARK: - Board Suggestion Actions

    private func acceptBoardSuggestion() {
        guard let itemID = pendingSuggestionItemID else {
            dismissBoardSuggestion()
            return
        }

        let boardName = pendingSuggestionBoardName
        let context = modelContext

        Task {
            // Find the item and clear pendingBoardSuggestion metadata
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == itemID })
            guard let item = try? context.fetch(descriptor).first else { return }

            // Check if a board with this name already exists (race condition guard)
            let boardDescriptor = FetchDescriptor<Board>()
            let allBoards = (try? context.fetch(boardDescriptor)) ?? []
            let existing = allBoards.first(where: {
                $0.title.localizedCaseInsensitiveCompare(boardName) == .orderedSame
            })

            let board: Board
            if let existingBoard = existing {
                board = existingBoard
            } else {
                let newBoard = Board(title: boardName)
                context.insert(newBoard)
                board = newBoard
            }

            if !item.boards.contains(where: { $0.id == board.id }) {
                item.boards.append(board)
            }
            item.metadata["pendingBoardSuggestion"] = nil
            try? context.save()
        }

        dismissBoardSuggestion()
    }

    private func dismissBoardSuggestion() {
        suggestionDismissTask?.cancel()
        suggestionDismissTask = nil

        withAnimation(.easeOut(duration: 0.2)) {
            showBoardSuggestion = false
        }
        pendingSuggestionItemID = nil
        pendingSuggestionBoardName = ""
    }

    private func scheduleAutoDismiss() {
        suggestionDismissTask?.cancel()
        suggestionDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismissBoardSuggestion()
            }
        }
    }
}

// MARK: - Capture Bar Overlay

struct CaptureBarOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Board.sortOrder) private var boards: [Board]
    @Binding var isPresented: Bool
    @State private var inputText = ""
    @State private var showConfirmation = false
    @FocusState private var isFocused: Bool

    // Board suggestion state
    @State private var pendingSuggestionItemID: UUID? = nil
    @State private var pendingSuggestionBoardName: String = ""
    @State private var showBoardSuggestion = false
    @State private var suggestionDismissTask: Task<Void, Never>? = nil

    var currentBoardID: UUID?

    private var isURL: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isURL ? "link" : "note.text")
                    .font(.groveMeta)
                    .foregroundStyle(Color.textMuted)
                    .frame(width: 16)

                TextField("", text: $inputText, prompt:
                    Text("Paste a URL or type a note...")
                        .font(.groveGhostText)
                        .foregroundStyle(Color.textMuted)
                )
                .textFieldStyle(.plain)
                .font(.groveBody)
                .foregroundStyle(Color.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    capture()
                }

                if !inputText.isEmpty {
                    Button {
                        capture()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.groveBody)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("⏎")
                    .font(.groveShortcut)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            if showBoardSuggestion {
                BoardSuggestionBanner(
                    boardName: pendingSuggestionBoardName,
                    onAccept: { acceptBoardSuggestion() },
                    onDismiss: { dismissBoardSuggestion() }
                )
                .padding(.vertical, Spacing.xs)
            }
        }
        .frame(width: 600)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderPrimary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .overlay {
            if showConfirmation {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.groveBody)
                    Text("Captured")
                        .font(.groveBodySmall)
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.bgCard)
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .groveNewBoardSuggestion)) { notification in
            guard let itemID = notification.userInfo?["itemID"] as? UUID,
                  let boardName = notification.userInfo?["boardName"] as? String,
                  !boardName.isEmpty else { return }

            if currentBoardID != nil { return }

            pendingSuggestionItemID = itemID
            pendingSuggestionBoardName = boardName
            withAnimation(.easeOut(duration: 0.2)) {
                showBoardSuggestion = true
            }
            scheduleAutoDismiss()
        }
        .onAppear {
            isFocused = true
        }
        .onExitCommand {
            dismiss()
        }
    }

    private func capture() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let viewModel = ItemViewModel(modelContext: modelContext)
        let item = viewModel.captureItem(input: trimmed)

        if let boardID = currentBoardID,
           let board = boards.first(where: { $0.id == boardID }) {
            viewModel.assignToBoard(item, board: board)
        }

        inputText = ""

        withAnimation(.easeIn(duration: 0.15)) {
            showConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showConfirmation = false
                // Don't auto-dismiss overlay if board suggestion is visible
                if !showBoardSuggestion {
                    dismiss()
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }

    // MARK: - Board Suggestion Actions

    private func acceptBoardSuggestion() {
        guard let itemID = pendingSuggestionItemID else {
            dismissBoardSuggestion()
            return
        }

        let boardName = pendingSuggestionBoardName
        let context = modelContext

        Task {
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == itemID })
            guard let item = try? context.fetch(descriptor).first else { return }

            let boardDescriptor = FetchDescriptor<Board>()
            let allBoards = (try? context.fetch(boardDescriptor)) ?? []
            let existing = allBoards.first(where: {
                $0.title.localizedCaseInsensitiveCompare(boardName) == .orderedSame
            })

            let board: Board
            if let existingBoard = existing {
                board = existingBoard
            } else {
                let newBoard = Board(title: boardName)
                context.insert(newBoard)
                board = newBoard
            }

            if !item.boards.contains(where: { $0.id == board.id }) {
                item.boards.append(board)
            }
            item.metadata["pendingBoardSuggestion"] = nil
            try? context.save()
        }

        dismissBoardSuggestion()
        dismiss()
    }

    private func dismissBoardSuggestion() {
        suggestionDismissTask?.cancel()
        suggestionDismissTask = nil

        withAnimation(.easeOut(duration: 0.2)) {
            showBoardSuggestion = false
        }
        pendingSuggestionItemID = nil
        pendingSuggestionBoardName = ""
    }

    private func scheduleAutoDismiss() {
        suggestionDismissTask?.cancel()
        suggestionDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismissBoardSuggestion()
                dismiss()
            }
        }
    }
}
