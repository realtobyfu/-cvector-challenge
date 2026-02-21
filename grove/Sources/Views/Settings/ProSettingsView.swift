import SwiftUI

struct ProSettingsView: View {
    @Environment(EntitlementService.self) private var entitlement
    @State private var showPaywall = false

    var body: some View {
        Form {
            Section("Plan") {
                HStack {
                    Text("Current plan")
                        .font(.groveBody)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(entitlement.tier.displayName)
                        .font(.groveBodySecondary)
                        .foregroundStyle(Color.textSecondary)
                }

                if entitlement.isTrialActive {
                    if let ends = entitlement.trialEndsAt {
                        Text("Trial ends \(ends.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.groveBodySmall)
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Trial is active.")
                            .font(.groveBodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                if entitlement.isPro {
                    Text("Pro is active.")
                        .font(.groveBodySmall)
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Button("View Pro Plan") {
                        showPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Section("Included in Pro") {
                ForEach(ProFeature.allCases) { feature in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.groveBody)
                            .foregroundStyle(Color.textPrimary)
                        Text(feature.summary)
                            .font(.groveBodySmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }

#if DEBUG
            Section("Debug") {
                Button("Force Free Tier") {
                    entitlement.downgradeToFree()
                }
                .buttonStyle(.bordered)

                Button("Force Pro Tier") {
                    entitlement.activatePro()
                }
                .buttonStyle(.bordered)
            }
#endif
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(focusedFeature: nil)
        }
    }
}
