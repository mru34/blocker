import SwiftUI

struct HomeView: View {
    @ObservedObject private var stats = BlockStats.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(stats.blockedToday)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                    Text("reels avoided today")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    NavigationLink {
                        FilteredSiteView(title: "Instagram", rules: .instagram)
                    } label: {
                        AppButtonLabel(name: "Instagram", systemImage: "camera", subtitle: "No Reels, no Explore")
                    }

                    NavigationLink {
                        FilteredSiteView(title: "YouTube", rules: .youtube)
                    } label: {
                        AppButtonLabel(name: "YouTube", systemImage: "play.rectangle", subtitle: "No Shorts")
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Blocker")
            .onAppear { stats.refresh() }
        }
    }
}

private struct AppButtonLabel: View {
    let name: String
    let systemImage: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.primary)
    }
}

#Preview {
    HomeView()
}
