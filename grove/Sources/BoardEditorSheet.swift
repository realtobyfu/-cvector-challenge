import SwiftUI

struct BoardEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State var title: String
    @State var selectedIcon: String
    @State var selectedColorHex: String

    let isEditing: Bool
    let onSave: (String, String?, String?) -> Void

    private static let defaultIcon = "folder"
    private static let defaultColor = "007AFF"

    init(board: Board? = nil, onSave: @escaping (String, String?, String?) -> Void) {
        if let board {
            self.isEditing = true
            _title = State(initialValue: board.title)
            _selectedIcon = State(initialValue: board.icon ?? Self.defaultIcon)
            _selectedColorHex = State(initialValue: board.color ?? Self.defaultColor)
        } else {
            self.isEditing = false
            _title = State(initialValue: "")
            _selectedIcon = State(initialValue: Self.defaultIcon)
            _selectedColorHex = State(initialValue: Self.defaultColor)
        }
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                Section("Board Name") {
                    TextField("Enter board name", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Icon") {
                    iconPicker
                }

                Section("Color") {
                    colorPicker
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()
            footer
        }
        .frame(width: 380, height: 480)
    }

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Board" : "New Board")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button(isEditing ? "Save" : "Create") {
                let icon = selectedIcon.isEmpty ? nil : selectedIcon
                let color = selectedColorHex.isEmpty ? nil : selectedColorHex
                onSave(title, icon, color)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    // MARK: - Icon Picker

    private static let iconOptions: [String] = [
        "folder", "book", "laptopcomputer", "brain",
        "lightbulb", "star", "heart", "hammer",
        "paintbrush", "music.note", "globe", "atom",
        "function", "terminal", "cpu", "network",
        "chart.bar", "doc.text", "photo", "film",
        "gamecontroller", "graduationcap", "flask", "wrench",
        "leaf", "bolt", "eye", "hand.raised",
        "person.2", "map", "flag", "bookmark"
    ]

    private var iconPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 8), count: 8), spacing: 8) {
            ForEach(Self.iconOptions, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .frame(width: 32, height: 32)
                        .background(
                            selectedIcon == icon
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Color Picker

    private static let colorOptions: [String] = [
        "007AFF", "34C759", "FF3B30", "FF9500",
        "AF52DE", "FF2D55", "5856D6", "00C7BE",
        "A2845E", "8E8E93", "FFD60A", "64D2FF"
    ]

    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 8), count: 8), spacing: 8) {
            ForEach(Self.colorOptions, id: \.self) { hex in
                Button {
                    selectedColorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 28, height: 28)
                        .overlay(
                            selectedColorHex == hex
                                ? Circle().stroke(Color.primary, lineWidth: 2)
                                : nil
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
            }
        }
    }
}
