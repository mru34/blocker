import SwiftUI

struct BlockedAppsView: View {
    // Placeholder list; Phase 5 replaces this with FamilyActivityPicker tokens.
    private let apps = ["Instagram", "YouTube"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(apps, id: \.self) { app in
                        Label(app, systemImage: "lock.fill")
                    }
                } footer: {
                    Text("Screen Time blocking comes later. This list is a placeholder.")
                }
            }
            .navigationTitle("Blocked apps")
        }
    }
}

#Preview {
    BlockedAppsView()
}
