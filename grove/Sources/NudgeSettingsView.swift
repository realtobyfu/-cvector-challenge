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
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Stale Inbox", isOn: $staleInboxEnabled)
                    .onChange(of: staleInboxEnabled) { _, newValue in
                        NudgeSettings.staleInboxEnabled = newValue
                    }
                Text("Alerts when inbox items pile up without triage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Connection Prompts", isOn: $connectionPromptEnabled)
                    .onChange(of: connectionPromptEnabled) { _, newValue in
                        NudgeSettings.connectionPromptEnabled = newValue
                    }
                Text("Suggests writing a synthesis note when you add multiple items on the same topic.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Streaks", isOn: $streakEnabled)
                    .onChange(of: streakEnabled) { _, newValue in
                        NudgeSettings.streakEnabled = newValue
                    }
                Text("Celebrates consecutive days of engagement with a board.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Continue Course", isOn: $continueCourseEnabled)
                    .onChange(of: continueCourseEnabled) { _, newValue in
                        NudgeSettings.continueCourseEnabled = newValue
                    }
                Text("Reminds you to continue your next lecture in a course.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Spaced Resurfacing") {
                Toggle("Enable spaced resurfacing", isOn: $spacedResurfacingEnabled)
                    .onChange(of: spacedResurfacingEnabled) { _, newValue in
                        NudgeSettings.spacedResurfacingEnabled = newValue
                    }
                Text("Items with annotations or connections enter a resurfacing queue. Interval adapts based on your engagement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Pause all resurfacing", isOn: $globalResurfacingPause)
                    .onChange(of: globalResurfacingPause) { _, newValue in
                        NudgeSettings.spacedResurfacingGlobalPause = newValue
                    }
                Text("Temporarily pause resurfacing for all items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let stats = queueStats {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Queue Dashboard")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            statBadge(value: stats.totalInQueue, label: "In Queue", color: .blue)
                            statBadge(value: stats.upcoming, label: "Upcoming", color: .green)
                            statBadge(value: stats.overdue, label: "Overdue", color: .orange)
                            statBadge(value: stats.paused, label: "Paused", color: .gray)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Analytics") {
                analyticsRow(type: .resurface, label: "Resurface")
                analyticsRow(type: .staleInbox, label: "Stale Inbox")
                analyticsRow(type: .connectionPrompt, label: "Connection Prompts")
                analyticsRow(type: .streak, label: "Streaks")
                analyticsRow(type: .continueCourse, label: "Continue Course")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .onAppear {
            loadQueueStats()
        }
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func loadQueueStats() {
        let service = ResurfacingService(modelContext: modelContext)
        queueStats = service.queueStats()
    }

    private func analyticsRow(type: NudgeType, label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            let actedOn = NudgeSettings.analyticsCount(type: type, actedOn: true)
            let dismissed = NudgeSettings.analyticsCount(type: type, actedOn: false)
            Text("Acted: \(actedOn)")
                .font(.caption)
                .foregroundStyle(.green)
            Text("Dismissed: \(dismissed)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
