import SwiftUI

/// Settings view for configuring LLM (AI) features.
/// Provides provider selection (Apple Intelligence / Groq), API key, model, base URL,
/// enable/disable toggle, token usage tracking with per-service breakdown, estimated cost,
/// and optional monthly budget limit.
struct AISettingsView: View {
    @State private var isEnabled = LLMServiceConfig.isEnabled
    @State private var providerType = LLMServiceConfig.providerType
    @State private var apiKey = LLMServiceConfig.apiKey
    @State private var model = LLMServiceConfig.model
    @State private var baseURL = LLMServiceConfig.baseURL
    @State private var refreshID = UUID()

    private var tracker: TokenTracker { TokenTracker.shared }

    var body: some View {
        Form {
            Section("AI Features") {
                Toggle("Enable AI features", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        LLMServiceConfig.isEnabled = newValue
                    }
                Text("When disabled, all AI-powered features (auto-tagging, suggestions, nudges, synthesis) are turned off.")
                    .font(.groveBodySmall)
                    .foregroundStyle(Color.textSecondary)
            }

            Section("Provider") {
                if LLMServiceConfig.isAppleIntelligenceSupported {
                    Picker("AI Provider", selection: $providerType) {
                        ForEach(LLMProviderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: providerType) { _, newValue in
                        LLMServiceConfig.providerType = newValue
                        refreshID = UUID()
                    }

                    if providerType == .appleIntelligence {
                        appleIntelligenceStatus
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud")
                            .foregroundStyle(Color.textSecondary)
                        Text("Using Groq cloud API. Apple Intelligence requires macOS 26 or later.")
                            .font(.groveBodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            if providerType == .groq || !LLMServiceConfig.isAppleIntelligenceSupported {
                groqConfigSection
            }

            statusSection

            tokenUsageSection

            serviceBreakdownSection

            budgetSection

            Section("Synthesis") {
                if LLMServiceConfig.isConfigured {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.textPrimary)
                        Text("Synthesis uses AI — generates theme analysis, wiki-links, and highlights your reflections.")
                            .font(.groveBodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .foregroundStyle(Color.textSecondary)
                        Text("Synthesis uses local keyword extraction. Configure AI above for richer, LLM-powered synthesis.")
                            .font(.groveBodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Text("Synthesize is available via the board header toolbar or tag cluster headers.")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400)
        .id(refreshID)
    }

    // MARK: - Apple Intelligence Status

    private var appleIntelligenceStatus: some View {
        Group {
            if AppleIntelligenceProvider.isAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.textPrimary)
                    Text("Apple Intelligence is available on this Mac.")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.textSecondary)
                    Text("Apple Intelligence is not available. Check that it's enabled in System Settings.")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Text("On-device inference. Free, private, no API key required.")
                .font(.groveBadge)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Groq Configuration Section

    private var groqConfigSection: some View {
        Section("Groq Configuration") {
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .onChange(of: apiKey) { _, newValue in
                    LLMServiceConfig.apiKey = newValue
                }
            Text("Your Groq API key. Get one at console.groq.com.")
                .font(.groveBadge)
                .foregroundStyle(Color.textTertiary)

            TextField("Model", text: $model)
                .textFieldStyle(.roundedBorder)
                .onChange(of: model) { _, newValue in
                    LLMServiceConfig.model = newValue
                }
            Text("Default: moonshotai/kimi-k2-instruct")
                .font(.groveBadge)
                .foregroundStyle(Color.textTertiary)

            TextField("Base URL", text: $baseURL)
                .textFieldStyle(.roundedBorder)
                .onChange(of: baseURL) { _, newValue in
                    LLMServiceConfig.baseURL = newValue
                }
            Text("Default: https://api.groq.com/openai/v1/chat/completions")
                .font(.groveBadge)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Image(systemName: LLMServiceConfig.isConfigured ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(LLMServiceConfig.isConfigured ? Color.textPrimary : Color.textTertiary)
                Text(statusText)
                    .font(.groveBodySmall)
                    .fontWeight(LLMServiceConfig.isConfigured ? .medium : .regular)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var statusText: String {
        if !isEnabled {
            return "AI features disabled"
        }
        if LLMServiceConfig.isConfigured {
            return "Ready — using \(providerType.displayName)"
        }
        if providerType == .groq {
            return "Not configured — enter an API key to enable AI features"
        }
        return "Apple Intelligence unavailable on this Mac"
    }

    // MARK: - Token Usage Section

    private var tokenUsageSection: some View {
        Section("Token Usage") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input tokens")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textSecondary)
                    Text(formatNumber(tracker.totalInputTokens))
                        .font(.custom("IBMPlexMono-SemiBold", size: 13))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output tokens")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textSecondary)
                    Text(formatNumber(tracker.totalOutputTokens))
                        .font(.custom("IBMPlexMono-SemiBold", size: 13))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textSecondary)
                    Text(formatNumber(tracker.totalTokens))
                        .font(.custom("IBMPlexMono-SemiBold", size: 13))
                        .foregroundStyle(Color.textPrimary)
                }
            }

            if providerType == .groq {
                HStack {
                    Text("Estimated cost")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(formatCost(tracker.estimatedCost))
                        .font(.custom("IBMPlexMono-SemiBold", size: 13))
                        .foregroundStyle(Color.textPrimary)
                }
            }

            HStack {
                Text("Total AI calls")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(formatNumber(tracker.callCount))
                    .font(.custom("IBMPlexMono-SemiBold", size: 13))
                    .foregroundStyle(Color.textPrimary)
            }

            if providerType == .groq {
                Text("Based on $1.50 per million tokens (blended rate).")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Text("Apple Intelligence runs on-device at no cost. Token counts are estimated.")
                    .font(.groveBadge)
                    .foregroundStyle(Color.textTertiary)
            }

            Button("Reset Usage") {
                tracker.resetAll()
                refreshID = UUID()
            }
        }
    }

    // MARK: - Service Breakdown Section

    private var serviceBreakdownSection: some View {
        Section("Usage by Service") {
            let services = tracker.usageByService
            if services.isEmpty {
                Text("No usage recorded yet.")
                    .font(.groveBodySecondary)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(services) { service in
                    HStack {
                        Text(displayName(for: service.service))
                            .font(.groveBodySecondary)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatNumber(service.totalTokens) + " tokens")
                                .font(.groveMeta)
                                .foregroundStyle(Color.textPrimary)
                            if providerType == .groq {
                                Text(formatCost(Double(service.totalTokens) / 1_000_000.0 * 1.50))
                                    .font(.groveBadge)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Budget Section

    @State private var budgetEnabled: Bool = TokenTracker.shared.budgetEnabled
    @State private var budgetText: String = {
        let budget = TokenTracker.shared.monthlyBudget
        return "\(budget / 1000)"
    }()

    private var budgetSection: some View {
        Section("Monthly Budget") {
            Toggle("Enable monthly budget limit", isOn: $budgetEnabled)
                .onChange(of: budgetEnabled) { _, newValue in
                    tracker.budgetEnabled = newValue
                }

            if budgetEnabled {
                HStack {
                    Text("Budget (thousands of tokens)")
                        .font(.groveBodySecondary)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    TextField("1000", text: $budgetText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(.groveShortcut)
                        .onChange(of: budgetText) { _, newValue in
                            if let val = Int(newValue), val > 0 {
                                tracker.monthlyBudget = val * 1000
                            }
                        }
                    Text("K")
                        .font(.groveShortcut)
                        .foregroundStyle(Color.textSecondary)
                }

                HStack {
                    Text("Used this month")
                        .font(.groveBadge)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(formatNumber(tracker.currentMonthTokens) + " / " + formatNumber(tracker.monthlyBudget))
                        .font(.groveMeta)
                        .foregroundStyle(Color.textPrimary)
                }

                if tracker.isBudgetExceeded {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.textPrimary)
                        Text("Monthly budget exceeded. AI features are paused until next month or budget increase.")
                            .font(.groveBodySmall)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            Text("When the budget is reached, AI features pause automatically. No further calls will be made.")
                .font(.groveBadge)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatCost(_ cost: Double) -> String {
        String(format: "$%.4f", cost)
    }

    private func displayName(for service: String) -> String {
        switch service {
        case "tagging": return "Auto-Tagging"
        case "suggestions": return "Connection Suggestions"
        case "reflection_prompts": return "Reflection Prompts"
        case "nudges": return "Smart Nudges"
        case "synthesis": return "Synthesis"
        case "digest": return "Weekly Digest"
        case "learning_path": return "Learning Paths"
        case "overview": return "Article Overview"
        case "dialectics": return "Dialectical Chat"
        default: return service.capitalized
        }
    }
}
