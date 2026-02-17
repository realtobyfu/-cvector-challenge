import SwiftUI
import SwiftData

/// A non-blocking nudge bar displayed at the top of the content area.
/// Shows one nudge at a time with action and dismiss buttons.
/// For resurface nudges, optionally shows a reflection prompt.
struct NudgeBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Nudge.createdAt, order: .reverse) private var allNudges: [Nudge]

    var onOpenItem: ((Item) -> Void)?
    var onTriageInbox: (() -> Void)?
    var resurfacingService: ResurfacingService?

    @State private var showReflectionPrompt = false
    @State private var reflectionText = ""

    private var currentNudge: Nudge? {
        allNudges.first { $0.status == .pending || $0.status == .shown }
    }

    var body: some View {
        if let nudge = currentNudge {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: nudge.type.iconName)
                        .font(.subheadline)
                        .foregroundStyle(nudge.type.accentColor)

                    Text(nudge.message)
                        .font(.subheadline)
                        .lineLimit(2)

                    Spacer()

                    // Reflection prompt toggle for resurface nudges
                    if nudge.type == .resurface, nudge.targetItem != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showReflectionPrompt.toggle()
                            }
                        } label: {
                            Image(systemName: "text.bubble")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        .help("Add a quick reflection")
                    }

                    Button(nudge.type.actionLabel) {
                        actOnNudge(nudge)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        dismissNudge(nudge)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                // Reflection prompt area
                if showReflectionPrompt, nudge.type == .resurface {
                    HStack(spacing: 8) {
                        TextField("What was the key insight from this?", text: $reflectionText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit {
                                submitReflection(for: nudge)
                            }

                        Button("Save") {
                            submitReflection(for: nudge)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(reflectionText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                if nudge.status == .pending {
                    nudge.status = .shown
                    try? modelContext.save()
                }
            }
            .onChange(of: currentNudge?.id) {
                // Reset reflection state when nudge changes
                showReflectionPrompt = false
                reflectionText = ""
            }
        }
    }

    private func submitReflection(for nudge: Nudge) {
        let text = reflectionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let item = nudge.targetItem else { return }

        // Create annotation from reflection
        let annotation = Annotation(item: item, content: text)
        modelContext.insert(annotation)

        // Record engagement on the item
        resurfacingService?.recordEngagement(for: item)

        // Mark nudge as acted on
        withAnimation(.easeOut(duration: 0.25)) {
            nudge.status = .actedOn
            NudgeSettings.recordAction(type: nudge.type, actedOn: true)
            try? modelContext.save()
        }

        reflectionText = ""
        showReflectionPrompt = false
    }

    private func actOnNudge(_ nudge: Nudge) {
        // For resurface nudges, record engagement
        if nudge.type == .resurface, let item = nudge.targetItem {
            resurfacingService?.recordEngagement(for: item)
        }

        withAnimation(.easeOut(duration: 0.25)) {
            nudge.status = .actedOn
            NudgeSettings.recordAction(type: nudge.type, actedOn: true)
            try? modelContext.save()
        }

        switch nudge.type {
        case .resurface, .continueCourse:
            if let item = nudge.targetItem {
                onOpenItem?(item)
            }
        case .staleInbox:
            onTriageInbox?()
        case .connectionPrompt, .streak:
            break
        }
    }

    private func dismissNudge(_ nudge: Nudge) {
        withAnimation(.easeOut(duration: 0.25)) {
            nudge.status = .dismissed
            NudgeSettings.recordAction(type: nudge.type, actedOn: false)
            try? modelContext.save()
        }
    }
}

// MARK: - NudgeType UI Helpers

extension NudgeType {
    var iconName: String {
        switch self {
        case .resurface: "arrow.clockwise.circle"
        case .staleInbox: "tray.full"
        case .connectionPrompt: "link.circle"
        case .streak: "flame"
        case .continueCourse: "graduationcap"
        }
    }

    var actionLabel: String {
        switch self {
        case .resurface: "Open"
        case .staleInbox: "Triage"
        case .connectionPrompt: "Connect"
        case .streak: "View"
        case .continueCourse: "Continue"
        }
    }

    var accentColor: Color {
        switch self {
        case .resurface: .blue
        case .staleInbox: .orange
        case .connectionPrompt: .purple
        case .streak: .red
        case .continueCourse: .green
        }
    }
}
