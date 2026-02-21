import SwiftUI

struct BoardSuggestionsView: View {
    let suggestions: [PromptBubble]
    @Binding var isSuggestionsCollapsed: Bool
    let onSelectSuggestion: (PromptBubble) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HomeSectionHeader(
                title: "DISCUSSION SUGGESTIONS",
                count: suggestions.count,
                isCollapsed: $isSuggestionsCollapsed
            )

            if !isSuggestionsCollapsed {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320, maximum: 400), spacing: Spacing.md)],
                    spacing: Spacing.md
                ) {
                    ForEach(suggestions) { bubble in
                        SuggestedConversationCard(
                            label: bubble.label,
                            title: bubble.prompt
                        ) {
                            onSelectSuggestion(bubble)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, Spacing.sm)
    }
}
