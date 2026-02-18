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
                    .foregroundStyle(Color(hex: "777777"))
                Text("SUGGESTED CONNECTIONS")
                    .font(.custom("IBMPlexMono", size: 10))
                    .fontWeight(.medium)
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: "777777"))
                Spacer()
                Button {
                    onDismissAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "AAAAAA"))
                }
                .buttonStyle(.plain)
            }

            ForEach(suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
        .padding(10)
        .frame(width: 300)
        .background(Color(hex: "FFFFFF"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(hex: "EBEBEB"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func suggestionRow(_ suggestion: ConnectionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.targetItem.type.iconName)
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "777777"))
                    .frame(width: 12)
                Text(suggestion.targetItem.title)
                    .font(.custom("IBMPlexSans-Regular", size: 12))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 4) {
                Text(suggestion.suggestedType.displayLabel)
                    .font(.custom("IBMPlexMono", size: 10))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(hex: "E8E8E8"))
                    .clipShape(Capsule())

                Text(suggestion.reason)
                    .font(.custom("IBMPlexSans-Regular", size: 11))
                    .foregroundStyle(Color(hex: "AAAAAA"))
                    .lineLimit(1)

                Spacer()

                Button {
                    onAccept(suggestion)
                } label: {
                    Text("Connect")
                        .font(.custom("IBMPlexSans-Regular", size: 11))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(Color(hex: "1A1A1A"))

                Button {
                    onDismiss(suggestion)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: "AAAAAA"))
            }
        }
        .padding(6)
        .background(Color(hex: "F7F7F7"))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(hex: "EBEBEB"), lineWidth: 1)
        )
    }
}
