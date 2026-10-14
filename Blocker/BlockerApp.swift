import SwiftUI

@main
struct BlockerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    BlockStats.shared.recordActiveDay()
                    // Instagram's site takes ~10 s to load, so start it now, before the user taps it.
                    SiteSession.preload(.instagram, rules: RulesStore.shared.rules.instagram)
                    await RulesStore.shared.refresh()
                    let rules = RulesStore.shared.rules
                    await RuleHealth.shared.sendReports(to: rules.healthReportURL, rulesVersion: rules.version)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    BlockStats.shared.recordActiveDay()
                    Task { await RulesStore.shared.refresh() }
                }
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            BlockedAppsView()
                .tabItem { Label("Blocked apps", systemImage: "lock.shield") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootTabView()
}
