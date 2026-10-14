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
    // Debug builds: launch with `-startTab blocked` (or `settings`) to open on that tab, for screenshots.
    @State private var tab = UserDefaults.standard.string(forKey: "startTab") ?? "home"

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag("home")

            BlockedAppsView()
                .tabItem { Label("Blocked apps", systemImage: "lock.shield") }
                .tag("blocked")

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag("settings")
        }
    }
}

#Preview {
    RootTabView()
}
