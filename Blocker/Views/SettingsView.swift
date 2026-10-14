import SwiftUI

struct SettingsView: View {
    @ObservedObject private var rulesStore = RulesStore.shared
    @State private var checking = false

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

                Section("About") {
                    LabeledContent("App version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
