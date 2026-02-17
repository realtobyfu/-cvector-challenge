import SwiftUI
import SwiftData

struct QuickCapturePanel: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            TextField("Paste a URL or type a note…", text: $inputText)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(8)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .focused($isFocused)
                .onSubmit {
                    capture()
                }

            HStack {
                if !inputText.isEmpty {
                    let isURL = detectIsURL(inputText)
                    Image(systemName: isURL ? "link" : "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(isURL ? "Will save as \(isVideoURL(inputText) ? "video" : "article")" : "Will save as note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("⏎ to capture")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 400)
        .onAppear {
            isFocused = true
        }
    }

    private func capture() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let viewModel = ItemViewModel(modelContext: modelContext)
        _ = viewModel.captureItem(input: trimmed)

        inputText = ""
        dismiss()
    }

    private func detectIsURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else { return false }
        return true
    }

    private func isVideoURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("youtube.com/watch")
            || lower.contains("youtu.be/")
            || lower.contains("vimeo.com/")
    }
}
