import SwiftUI
import SwiftData

/// Non-blocking popover showing connection suggestions after item/annotation save.
/// Shows top 3 suggestions with accept/dismiss actions.
struct ConnectionSuggestionPopover: View {
    let sourceItem: Item
    let suggestions: [ConnectionSuggestion]
    let onAccept: (ConnectionSuggestion) -> Void
    let onDismiss: (ConnectionSuggestion) -> Void
    let onDismissAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Suggested Connections")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onDismissAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
        .padding(10)
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private func suggestionRow(_ suggestion: ConnectionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.targetItem.type.iconName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text(suggestion.targetItem.title)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 4) {
                Text(suggestion.suggestedType.displayLabel)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())

                Text(suggestion.reason)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()

                Button {
                    onAccept(suggestion)
                } label: {
                    Text("Connect")
                        .font(.caption2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)

                Button {
                    onDismiss(suggestion)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
