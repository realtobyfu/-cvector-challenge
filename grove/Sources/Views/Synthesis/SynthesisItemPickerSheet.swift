import SwiftUI

// MARK: - SynthesisItemPickerSheet

struct SynthesisItemPickerSheet: View {
    let items: [Item]
    let scopeTitle: String
    let onConfirm: ([Item]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID>

    init(items: [Item], scopeTitle: String, onConfirm: @escaping ([Item]) -> Void) {
        self.items = items
        self.scopeTitle = scopeTitle
        self.onConfirm = onConfirm
        _selectedIDs = State(initialValue: Set(items.map(\.id)))
    }

    private var selectedItems: [Item] {
        items.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            selectAllBar
            Divider()
            itemList
            Divider()
            footer
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Select Items to Synthesize")
                    .font(.groveItemTitle)
                    .foregroundStyle(Color.textPrimary)
                Text(scopeTitle)
                    .font(.groveMeta)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Text("\(selectedIDs.count) selected")
                .font(.groveBadge)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentBadge)
                .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - Select All / Deselect All

    private var selectAllBar: some View {
        HStack(spacing: 6) {
            Button("Select All") {
                selectedIDs = Set(items.map(\.id))
            }
            .font(.groveBodySmall)
            .foregroundStyle(Color.textSecondary)
            .buttonStyle(.plain)
            .disabled(selectedIDs.count == items.count)

            Text("·")
                .font(.groveBodySmall)
                .foregroundStyle(Color.textTertiary)

            Button("Deselect All") {
                selectedIDs = []
            }
            .font(.groveBodySmall)
            .foregroundStyle(Color.textSecondary)
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    pickerRow(item: item)
                    Divider()
                        .padding(.leading, 48)
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Synthesize (\(selectedIDs.count))") {
                onConfirm(selectedItems)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedIDs.count < 2)
        }
        .padding()
    }

    // MARK: - Row

    private func pickerRow(item: Item) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        return HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.groveBody)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textMuted)
                .frame(width: 20)

            Image(systemName: item.type.iconName)
                .font(.groveMeta)
                .foregroundStyle(Color.textMuted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.groveBody)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let firstBoard = item.boards.first {
                        Text(firstBoard.title)
                            .font(.groveMeta)
                            .foregroundStyle(Color.textTertiary)
                    }
                    if !item.tags.isEmpty && item.boards.first != nil {
                        Text("·")
                            .font(.groveMeta)
                            .foregroundStyle(Color.textTertiary)
                    }
                    ForEach(Array(item.tags.prefix(2)), id: \.id) { tag in
                        Text(tag.name)
                            .font(.groveMeta)
                            .foregroundStyle(Color.textSecondary)
                    }
                    if item.tags.count > 2 {
                        Text("+\(item.tags.count - 2)")
                            .font(.groveMeta)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Spacer()

            Text(item.updatedAt.pickerRelativeShort)
                .font(.groveMeta)
                .foregroundStyle(Color.textTertiary)

            GrowthStageIndicator(stage: item.growthStage)
                .help("\(item.growthStage.displayName) — \(item.depthScore) pts")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedIDs.remove(item.id)
            } else {
                selectedIDs.insert(item.id)
            }
        }
    }
}

// MARK: - Date Helper

private extension Date {
    var pickerRelativeShort: String {
        let diff = Date().timeIntervalSince(self)
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        if diff < 86400 * 7 { return "\(Int(diff / 86400))d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}
