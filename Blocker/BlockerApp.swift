import SwiftUI

@main
struct BlockerApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task { await RulesStore.shared.refresh() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
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
