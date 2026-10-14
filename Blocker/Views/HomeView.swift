import Charts
import SwiftUI

struct HomeView: View {
    @ObservedObject private var stats = BlockStats.shared
    @ObservedObject private var rulesStore = RulesStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TodayCard(stats: stats)
                    WeekCard(days: stats.lastSevenDays)

                    VStack(spacing: 12) {
                        NavigationLink {
                            FilteredSiteView(title: "Instagram", site: .instagram, rules: rulesStore.rules.instagram)
                        } label: {
                            AppButtonLabel(name: "Instagram", systemImage: "camera", subtitle: "No Reels, no Explore")
                        }

                        NavigationLink {
                            FilteredSiteView(title: "YouTube", site: .youtube, rules: rulesStore.rules.youtube)
                        } label: {
                            AppButtonLabel(name: "YouTube", systemImage: "play.rectangle", subtitle: "No Shorts")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Blocker")
            .onAppear { stats.refresh() }
        }
    }
}

/// Today's headline number and what it adds up to.
private struct TodayCard: View {
    @ObservedObject var stats: BlockStats

    var body: some View {
        VStack(spacing: 6) {
            Text("Reels avoided today")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("\(stats.avoidedToday)")
                .font(.system(size: 64, weight: .semibold))
            Text("≈ \(BlockStats.timeSaved(reels: stats.avoidedToday)) saved")
                .font(.headline)
            Text("\(stats.blockedToday) blocked · \(stats.hiddenToday) hidden in your feed")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Reels avoided per day for the last week. Tap a bar to see that day's number.
private struct WeekCard: View {
    let days: [BlockStats.Day]
    @State private var selected: Date?

    private var weekTotal: Int { days.reduce(0) { $0 + $1.total } }

    private var caption: String {
        if let selected, let day = days.first(where: { $0.date == selected }) {
            return "\(label(for: day)): \(day.total) reels · ≈ \(BlockStats.timeSaved(reels: day.total))"
        }
        return "\(weekTotal) reels · ≈ \(BlockStats.timeSaved(reels: weekTotal)) saved"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last 7 days")
                .font(.headline)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", label(for: day)),
                    y: .value("Reels avoided", day.total),
                    width: .ratio(0.5)
                )
                .cornerRadius(4)
                .foregroundStyle(isHighlighted(day) ? Color.chartToday : Color.chartPast)
                .annotation(position: .top, spacing: 4) {
                    if isHighlighted(day), day.total > 0 {
                        Text("\(day.total)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .accessibilityLabel(label(for: day))
                .accessibilityValue("\(day.total) reels avoided")
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel().foregroundStyle(Color(.secondaryLabel))
                }
            }
            .chartXAxis {
                AxisMarks { AxisValueLabel().foregroundStyle(Color(.secondaryLabel)) }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                if let name: String = proxy.value(atX: x) {
                                    selected = days.first { label(for: $0) == name }?.date
                                }
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { selected = nil }
                            })
                }
            }
            .frame(height: 150)
            .padding(.top, 12)

            Text("Time saved assumes about \(BlockStats.secondsPerReel) seconds per reel.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Today, or the tapped bar while one is selected.
    private func isHighlighted(_ day: BlockStats.Day) -> Bool {
        if let selected { return day.date == selected }
        return Calendar.current.isDateInToday(day.date)
    }

    private func label(for day: BlockStats.Day) -> String {
        if Calendar.current.isDateInToday(day.date) { return "Today" }
        return day.date.formatted(.dateTime.weekday(.abbreviated))
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
                .foregroundStyle(Color.brandInk)
                .frame(width: 44, height: 44)
                .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(.primary)
    }
}

#Preview {
    HomeView()
}
