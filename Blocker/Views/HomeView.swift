import Charts
import SwiftUI

struct HomeView: View {
    @ObservedObject private var stats = BlockStats.shared
    @ObservedObject private var rulesStore = RulesStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Our own header so the streak pill sits next to the title; a toolbar item
                    // gets squashed into an icon-only glass button on iOS 26.
                    HStack(alignment: .center) {
                        Text("Blocker")
                            .font(.largeTitle.bold())
                        Spacer()
                        StreakPill(days: stats.streak)
                    }
                    .padding(.top, 8)

                    HeroCard(stats: stats)

                    HStack(spacing: 12) {
                        NavigationLink {
                            FilteredSiteView(title: "Instagram", site: .instagram, rules: rulesStore.rules.instagram)
                        } label: {
                            AppTile(name: "Instagram", systemImage: "camera", subtitle: "No Reels")
                        }
                        NavigationLink {
                            FilteredSiteView(title: "YouTube", site: .youtube, rules: rulesStore.rules.youtube)
                        } label: {
                            AppTile(name: "YouTube", systemImage: "play.rectangle", subtitle: "No Shorts")
                        }
                    }

                    BadgesRow(stats: stats)
                    WeekCard(days: stats.lastSevenDays)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Blocker") // shown as the back button on the Instagram/YouTube screens
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { stats.refresh() }
        }
    }
}

/// The big yellow card: today's number and what it adds up to.
private struct HeroCard: View {
    @ObservedObject var stats: BlockStats

    private var sentence: String {
        stats.avoidedToday == 0
            ? "Every reel you skip is time back."
            : "That's \(BlockStats.timeSavedInWords(reels: stats.avoidedToday)) back in your day."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reels avoided today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandYellowSecondary)
            Text("\(stats.avoidedToday)")
                .font(.system(size: 76, weight: .bold))
                .tracking(-2)
                .foregroundStyle(Color.brandInk)
                .padding(.vertical, -4)
            Text(sentence)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brandInk)
            Text("\(stats.blockedToday) blocked · \(stats.hiddenToday) hidden in your feed")
                .font(.footnote)
                .foregroundStyle(Color.brandYellowSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct AppTile: View {
    let name: String
    let systemImage: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.brandYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.brandTile, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text(days <= 1 ? "Day 1" : "\(days)-day streak")
        }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.brandInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.brandYellow, in: Capsule())
            .accessibilityLabel(days <= 1 ? "First day using Blocker" : "\(days) days in a row using Blocker")
    }
}

/// Milestones, earned ones in yellow and the next ones locked.
private struct BadgesRow: View {
    @ObservedObject var stats: BlockStats

    private struct Badge: Identifiable {
        let title: String
        let systemImage: String
        let earned: Bool
        var id: String { title }
    }

    private var badges: [Badge] {
        [
            Badge(title: "First reel", systemImage: "hand.raised.fill", earned: stats.totalAvoided >= 1),
            Badge(title: "100 avoided", systemImage: "trophy.fill", earned: stats.totalAvoided >= 100),
            Badge(title: "7-day streak", systemImage: "flame.fill", earned: stats.streak >= 7),
            Badge(title: "1,000 avoided", systemImage: "crown.fill", earned: stats.totalAvoided >= 1000),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Badges")
                .font(.headline)
            HStack(spacing: 8) {
                ForEach(badges) { badge in
                    VStack(spacing: 6) {
                        Image(systemName: badge.earned ? badge.systemImage : "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(badge.title)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(badge.earned ? Color.brandInk : Color(.tertiaryLabel))
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .padding(.horizontal, 4)
                    .background(badge.earned ? Color.brandYellow : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(badge.title), \(badge.earned ? "earned" : "locked")")
                }
            }
        }
    }
}

/// Reels avoided per day for the last week. Tap a bar to see that day's number.
private struct WeekCard: View {
    let days: [BlockStats.Day]
    @State private var selected: Date?

    private var weekTotal: Int { days.reduce(0) { $0 + $1.total } }

    private var caption: String {
        if let selected, let day = days.first(where: { $0.date == selected }) {
            return "\(label(for: day)): \(day.total) reels"
        }
        return "\(BlockStats.timeSaved(reels: weekTotal)) saved"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(.headline)
                Spacer()
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
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
                AxisMarks(values: days.map(\.date)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let isToday = Calendar.current.isDateInToday(date)
                            Text(isToday ? "Today" : date.formatted(.dateTime.weekday(.narrow)))
                                .fontWeight(isToday ? .semibold : .regular)
                                .foregroundStyle(isToday ? Color(.label) : Color(.secondaryLabel))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selected = days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.date
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
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

#Preview {
    HomeView()
}
