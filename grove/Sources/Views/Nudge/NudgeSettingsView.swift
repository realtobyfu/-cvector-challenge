import SwiftUI
import SwiftData

/// Settings view for configuring nudge behavior.
/// Accessible from the app's Settings window.
struct NudgeSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var resurfaceEnabled = NudgeSettings.resurfaceEnabled
    @State private var staleInboxEnabled = NudgeSettings.staleInboxEnabled
    @State private var connectionPromptEnabled = NudgeSettings.connectionPromptEnabled
    @State private var streakEnabled = NudgeSettings.streakEnabled
    @State private var continueCourseEnabled = NudgeSettings.continueCourseEnabled
    @State private var scheduleIntervalHours = NudgeSettings.scheduleIntervalHours
    @State private var maxNudgesPerDay = NudgeSettings.maxNudgesPerDay
    @State private var spacedResurfacingEnabled = NudgeSettings.spacedResurfacingEnabled
    @State private var globalResurfacingPause = NudgeSettings.spacedResurfacingGlobalPause
    @State private var digestEnabled = NudgeSettings.digestEnabled
    @State private var digestDayOfWeek = NudgeSettings.digestDayOfWeek
    @State private var queueStats: ResurfacingService.QueueStats?

    private static let intervalOptions: [(label: String, value: Int)] = [
        ("Every 2 Hours", 2),
        ("Every 4 Hours", 4),
        ("Every 8 Hours", 8),
        ("Every 12 Hours", 12),
        ("Once a Day", 24)
    ]

    var body: some View {
        Form {
            Section("Nudge Categories") {
                Toggle("Resurface", isOn: $resurfaceEnabled)
                    .onChange(of: resurfaceEnabled) { _, newValue in
                        NudgeSettings.resurfaceEnabled = newValue
                    }
                Text("Reminds you about saved items you haven't revisited.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                Toggle("Stale Inbox", isOn: $staleInboxEnabled)
                    .onChange(of: staleInboxEnabled) { _, newValue in
                        NudgeSettings.staleInboxEnabled = newValue
                    }
                Text("Alerts when inbox items pile up without triage.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                Toggle("Connection Prompts", isOn: $connectionPromptEnabled)
                    .onChange(of: connectionPromptEnabled) { _, newValue in
                        NudgeSettings.connectionPromptEnabled = newValue
                    }
                Text("Suggests writing a synthesis note when you add multiple items on the same topic.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                Toggle("Streaks", isOn: $streakEnabled)
                    .onChange(of: streakEnabled) { _, newValue in
                        NudgeSettings.streakEnabled = newValue
                    }
                Text("Celebrates consecutive days of engagement with a board.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                Toggle("Continue Course", isOn: $continueCourseEnabled)
                    .onChange(of: continueCourseEnabled) { _, newValue in
                        NudgeSettings.continueCourseEnabled = newValue
                    }
                Text("Reminds you to continue your next lecture in a course.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)
            }

            Section("Spaced Resurfacing") {
                Toggle("Enable spaced resurfacing", isOn: $spacedResurfacingEnabled)
                    .onChange(of: spacedResurfacingEnabled) { _, newValue in
                        NudgeSettings.spacedResurfacingEnabled = newValue
                    }
                Text("Items with annotations or connections enter a resurfacing queue. Interval adapts based on your engagement.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                Toggle("Pause all resurfacing", isOn: $globalResurfacingPause)
                    .onChange(of: globalResurfacingPause) { _, newValue in
                        NudgeSettings.spacedResurfacingGlobalPause = newValue
                    }
                Text("Temporarily pause resurfacing for all items.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                if let stats = queueStats {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Queue Dashboard")
                            .sectionHeaderStyle()

                        HStack(spacing: Spacing.lg) {
                            statBadge(value: stats.totalInQueue, label: "In Queue")
                            statBadge(value: stats.upcoming, label: "Upcoming")
                            statBadge(value: stats.overdue, label: "Overdue")
                            statBadge(value: stats.paused, label: "Paused")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Schedule") {
                Picker("Check Frequency", selection: $scheduleIntervalHours) {
                    ForEach(Self.intervalOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .onChange(of: scheduleIntervalHours) { _, newValue in
                    NudgeSettings.scheduleIntervalHours = newValue
                }

                Stepper("Max per day: \(maxNudgesPerDay)", value: $maxNudgesPerDay, in: 1...10)
                    .onChange(of: maxNudgesPerDay) { _, newValue in
                        NudgeSettings.maxNudgesPerDay = newValue
                    }
                Text("Users with high engagement (3+ acted-on nudges in 7 days) may see more.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)
            }

            Section("Weekly Digest") {
                Toggle("Weekly digest", isOn: $digestEnabled)
                    .onChange(of: digestEnabled) { _, newValue in
                        NudgeSettings.digestEnabled = newValue
                    }
                Text("Generates a summary of your learning activity each week.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                Picker("Day of week", selection: $digestDayOfWeek) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Tuesday").tag(3)
                    Text("Wednesday").tag(4)
                    Text("Thursday").tag(5)
                    Text("Friday").tag(6)
                    Text("Saturday").tag(7)
                }
                .onChange(of: digestDayOfWeek) { _, newValue in
                    NudgeSettings.digestDayOfWeek = newValue
                }

                digestStatusText
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)

                if !LLMServiceConfig.isConfigured {
                    Text("AI is not configured. Digest will use a local summary.")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Section("Smart Nudges (AI)") {
                if LLMServiceConfig.isConfigured {
                    Text("AI-powered nudges generate on app launch. One per launch, max.")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Text("Enable AI in Settings > AI to get smart nudges. Falls back to time-based nudges when AI is off.")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Section("Analytics") {
                analyticsRow(type: .resurface, label: "Resurface")
                analyticsRow(type: .staleInbox, label: "Stale Inbox")
                analyticsRow(type: .connectionPrompt, label: "Connection Prompts")
                analyticsRow(type: .streak, label: "Streaks")
                analyticsRow(type: .continueCourse, label: "Continue Course")
                analyticsRow(type: .reflectionPrompt, label: "AI: Reflect")
                analyticsRow(type: .contradiction, label: "AI: Contradiction")
                analyticsRow(type: .knowledgeGap, label: "AI: Knowledge Gap")
                analyticsRow(type: .synthesisPrompt, label: "AI: Synthesis")
                analyticsRow(type: .continueCourse, label: "AI: Course Continue")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .onAppear {
            loadQueueStats()
        }
    }

    private func statBadge(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.groveItemTitle)
                .monospacedDigit()
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.groveBadge)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var digestStatusText: Text {
        let lastGenerated = NudgeSettings.digestLastGeneratedAt
        if lastGenerated > 0 {
            let date = Date(timeIntervalSince1970: lastGenerated)
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return Text("Last generated \(formatter.localizedString(for: date, relativeTo: .now))")
        } else {
            return Text("No digest generated yet.")
        }
    }

    private func loadQueueStats() {
        let service = ResurfacingService(modelContext: modelContext)
        queueStats = service.queueStats()
    }

    private func analyticsRow(type: NudgeType, label: String) -> some View {
        HStack {
            Text(label)
                .font(.groveBody)
            Spacer()
            let actedOn = NudgeSettings.analyticsCount(type: type, actedOn: true)
            let dismissed = NudgeSettings.analyticsCount(type: type, actedOn: false)
            Text("Acted: \(actedOn)")
                .font(.groveMeta)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)
            Text("Dismissed: \(dismissed)")
                .font(.groveMeta)
                .foregroundStyle(Color.textSecondary)
        }
    }
}
