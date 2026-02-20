import SwiftUI
import SwiftData

struct QuickCapturePanel: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var linkText = ""
    @State private var showInvalidLink = false
    @FocusState private var isFocused: Bool

    private var validLink: String? {
        normalizedLink(from: linkText)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "link")
                    .font(.groveItemTitle)
                    .foregroundStyle(Color.textSecondary)
                Text("Paste a Link")
                    .font(.groveBodyMedium)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("Close quick capture")
                .accessibilityHint("Dismisses the quick capture window.")
            }

            HStack(spacing: Spacing.sm) {
                TextField("https://example.com", text: $linkText)
                    .textFieldStyle(.plain)
                    .font(.groveBody)
                    .focused($isFocused)
                    .onSubmit {
                        capture()
                    }
                    .onChange(of: linkText) { _, _ in
                        showInvalidLink = false
                    }

                Button {
                    capture()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.groveBody)
                        .foregroundStyle(validLink == nil ? Color.textTertiary : Color.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(validLink == nil)
                .accessibilityLabel("Capture link")
            }
            .padding(Spacing.sm)
            .background(Color.bgInput)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderInput, lineWidth: 1)
            )

            Text(showInvalidLink ? "Enter a valid http(s) link." : "Press Return to capture.")
                .font(.groveMeta)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(Spacing.lg)
        .frame(width: 420)
        .onAppear {
            isFocused = true
        }
    }

    private func capture() {
        guard let validLink else {
            showInvalidLink = true
            return
        }

        let captureService = CaptureService(modelContext: modelContext)
        _ = captureService.captureItem(input: validLink)

        linkText = ""
        showInvalidLink = false
        dismiss()
    }

    private func normalizedLink(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = validHTTPURL(trimmed) {
            return direct.absoluteString
        }
        if !trimmed.contains("://"), let prefixed = validHTTPURL("https://\(trimmed)") {
            return prefixed.absoluteString
        }
        return nil
    }

    private func validHTTPURL(_ raw: String) -> URL? {
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty,
              let url = components.url else {
            return nil
        }
        return url
    }
}
