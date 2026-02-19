import SwiftUI
import SwiftData

struct BoardSuggestionsView: View {
    let suggestions: [Suggestion]
    @Binding var isSuggestionsCollapsed: Bool
    @Binding var openedItem: Item?
    @Binding var selectedItem: Item?
    var onRefresh: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "Suggestions",
                count: suggestions.count,
                isCollapsed: $isSuggestionsCollapsed
            )

            if !isSuggestionsCollapsed {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 200, maximum: 350), spacing: Spacing.md)],
                    spacing: Spacing.md
                ) {
                    ForEach(suggestions) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, Spacing.sm)
    }

    private func suggestionCard(_ suggestion: Suggestion) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentSelection)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(suggestion.type == .nudge ? (suggestion.nudge?.type.actionLabel ?? "NUDGE").uppercased() : suggestion.type.rawValue)
                        .font(.groveBadge)
                        .tracking(0.8)
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    if let nudge = suggestion.nudge {
                        Button {
                            dismissNudge(nudge)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    Image(systemName: suggestion.nudge?.type.iconName ?? suggestion.type.systemImage)
                        .font(.groveBodySecondary)
                        .foregroundStyle(Color.textSecondary)
                    Text(suggestion.title)
                        .font(.groveBody)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                }

                if let nudge = suggestion.nudge {
                    Button {
                        actOnNudge(nudge)
                    } label: {
                        Text(nudge.type.actionLabel)
                            .font(.groveBadge)
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentBadge)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(suggestion.reason)
                        .font(.groveBodySecondary)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .cardStyle(cornerRadius: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if suggestion.nudge != nil {
                // nudge cards have their own Button — do nothing on background tap
            } else if suggestion.type == .reflect, let item = suggestion.item {
                let prompt = "What are your key thoughts on \"\(item.title)\"?"
                NotificationCenter.default.post(name: .groveNewNoteWithPrompt, object: prompt)
            } else if let item = suggestion.item {
                openedItem = item
                selectedItem = item
            }
        }
    }

    private func actOnNudge(_ nudge: Nudge) {
        withAnimation(.easeOut(duration: 0.15)) {
            nudge.status = .actedOn
            NudgeSettings.recordAction(type: nudge.type, actedOn: true)
            try? modelContext.save()
        }
        if let item = nudge.targetItem {
            openedItem = item
            selectedItem = item
        }
        onRefresh()
    }

    private func dismissNudge(_ nudge: Nudge) {
        withAnimation(.easeOut(duration: 0.15)) {
            nudge.status = .dismissed
            NudgeSettings.recordAction(type: nudge.type, actedOn: false)
            try? modelContext.save()
        }
        onRefresh()
    }
}
