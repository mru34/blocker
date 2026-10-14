import SwiftUI

struct SettingsView: View {
    @ObservedObject private var rulesStore = RulesStore.shared
    @ObservedObject private var health = RuleHealth.shared
    @State private var checking = false
    @AppStorage(Diagnostics.defaultsKey) private var diagnosticLogging = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Version", value: "\(rulesStore.rules.version)")
                    LabeledContent("Last checked", value: rulesStore.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "Not yet")
                    Button(checking ? "Checking…" : "Check for new rules") {
                        checking = true
                        Task {
                            await rulesStore.refresh()
                            checking = false
                        }
                    }
                    .disabled(checking || RulesStore.remoteURL == nil)
                } header: {
                    Text("Blocking rules")
                } footer: {
                    if RulesStore.remoteURL == nil {
                        Text("No rules server set yet, so the built-in rules are used.")
                    }
                }

                Section {
                    RuleHealthRow(name: "Instagram", rules: rulesStore.rules.instagram, health: health)
                    RuleHealthRow(name: "YouTube", rules: rulesStore.rules.youtube, health: health)
                } header: {
                    Text("Rule health today")
                } footer: {
                    Text(rulesStore.rules.healthReportURL == nil
                         ? "Checks that the blocking rules still match Instagram and YouTube. Stays on this phone."
                         : "Checks that the blocking rules still match Instagram and YouTube. Anonymous daily counts (no account, links or names) help us notice when a site changes.")
                }

                #if DEBUG
                Section {
                    Toggle("Diagnostic logging", isOn: $diagnosticLogging)
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Logs page activity for debugging over the cable. Uses a little battery. Takes effect the next time you open Instagram or YouTube.")
                }
                #endif

                Section("About") {
                    LabeledContent("App version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct RuleHealthRow: View {
    let name: String
    let rules: SiteRules
    @ObservedObject var health: RuleHealth

    var body: some View {
        let today = health.today(for: rules.domain)
        let warnings = health.warnings(for: rules)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(warnings.isEmpty ? "Working" : "Needs a look",
                      systemImage: warnings.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(warnings.isEmpty ? .green : .orange)
                Text(name).font(.headline)
                Spacer()
                Text(warnings.isEmpty ? "Working" : "Needs a look")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(today.postsSeen > 0
                 ? "\(today.postsSeen) posts seen · \(today.reelsHidden) reels hidden · \(today.pageLoads) page loads"
                 : "\(today.pageLoads) page loads · \(today.matchedSelectors.count) of \(rules.hideSelectors.count + rules.collapseSelectors.count) rules matched")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(warnings) { warning in
                Text(warning.text)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SettingsView()
}
