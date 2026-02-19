import SwiftUI

struct SmartBoardPickerSheet: View {
    let boards: [Board]
    let suggestedName: String
    let recommendedBoardID: UUID?
    let prioritizedBoardIDs: [UUID]
    let onSelectBoard: (Board) -> Void
    let onCreateBoard: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var normalizedSuggestedName: String {
        BoardSuggestionEngine.cleanedBoardName(suggestedName)
    }

    private var normalizedQuery: String {
        BoardSuggestionEngine.cleanedBoardName(query)
    }

    private var boardNameCandidate: String {
        let candidate = normalizedQuery.isEmpty ? normalizedSuggestedName : normalizedQuery
        return BoardSuggestionEngine.cleanedBoardName(candidate)
    }

    private var exactExistingBoard: Board? {
        guard !boardNameCandidate.isEmpty else { return nil }
        return boards.first { $0.title.localizedCaseInsensitiveCompare(boardNameCandidate) == .orderedSame }
    }

    private var canCreateBoard: Bool {
        !boardNameCandidate.isEmpty && exactExistingBoard == nil
    }

    private var rankedBoards: [Board] {
        let filtered: [Board]
        if normalizedQuery.isEmpty {
            filtered = boards
        } else {
            filtered = boards.filter { board in
                board.title.localizedStandardContains(normalizedQuery)
                    || (board.boardDescription?.localizedStandardContains(normalizedQuery) ?? false)
            }
        }

        return filtered.sorted { lhs, rhs in
            boardRank(for: lhs) > boardRank(for: rhs)
        }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: 4) {
                Text("Assign to Board")
                    .font(.groveItemTitle)

                if !normalizedSuggestedName.isEmpty {
                    Text("Suggested: \(normalizedSuggestedName)")
                        .font(.groveBodySecondary)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.top)

            TextField("Search boards or type a new board name", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.groveBody)
                .padding(.horizontal)
                .onSubmit {
                    if let exactExistingBoard {
                        onSelectBoard(exactExistingBoard)
                        dismiss()
                    } else if canCreateBoard {
                        onCreateBoard(boardNameCandidate)
                        dismiss()
                    }
                }

            if canCreateBoard {
                Button {
                    onCreateBoard(boardNameCandidate)
                    dismiss()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.textSecondary)
                        Text("Create \"\(boardNameCandidate)\"")
                            .font(.groveBody)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.bgInput)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            if rankedBoards.isEmpty {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.groveItemTitle)
                        .foregroundStyle(Color.textTertiary)
                    Text("No matching boards")
                        .font(.groveBody)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(rankedBoards) { board in
                    Button {
                        onSelectBoard(board)
                        dismiss()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            if let hex = board.color {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 10, height: 10)
                            }

                            Image(systemName: board.icon ?? "folder")
                                .font(.groveBodySecondary)
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(board.title)
                                    .font(.groveBody)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                Text("\(board.items.count) items")
                                    .font(.groveMeta)
                                    .foregroundStyle(Color.textTertiary)
                            }

                            Spacer()

                            if board.id == recommendedBoardID {
                                Text("Best Match")
                                    .font(.groveBadge)
                                    .foregroundStyle(Color.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentBadge)
                                    .clipShape(Capsule())
                            } else if board.isSmart {
                                Text("Legacy Smart")
                                    .font(.groveBadge)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .padding(.horizontal, 4)
            }

            HStack {
                Spacer()
                Button("Skip") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 420, height: 470)
    }

    private func boardRank(for board: Board) -> Double {
        var score = 0.0

        if board.id == recommendedBoardID {
            score += 100
        }

        if let index = prioritizedBoardIDs.firstIndex(of: board.id) {
            score += Double(max(0, 60 - (index * 10)))
        }

        if board.title.localizedCaseInsensitiveCompare(normalizedSuggestedName) == .orderedSame {
            score += 70
        }

        if !normalizedQuery.isEmpty {
            let queryLower = normalizedQuery.lowercased()
            let titleLower = board.title.lowercased()
            if titleLower == queryLower {
                score += 70
            } else if titleLower.hasPrefix(queryLower) {
                score += 45
            } else if board.title.localizedStandardContains(normalizedQuery) {
                score += 25
            }

            if let description = board.boardDescription,
               description.localizedStandardContains(normalizedQuery) {
                score += 8
            }
        }

        score += min(Double(board.items.count), 20)

        if board.isSmart {
            score -= 5
        }

        return score
    }
}
