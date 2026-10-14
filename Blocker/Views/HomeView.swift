import SwiftUI

/// Home borrows the icon's language: a tilted poster number with the red "no play" sticker
/// slapped on it, the apps on a solid band, the week as stacks of film frames (the reels you
/// didn't watch), and milestones as a sticker sheet.
struct HomeView: View {
    @ObservedObject private var stats = BlockStats.shared
    @ObservedObject private var rulesStore = RulesStore.shared

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Hero(stats: stats)
                    AppsBand(rules: rulesStore.rules)
                    VStack(alignment: .leading, spacing: 36) {
                        FilmWeek(days: stats.lastSevenDays)
                        StickerSheet(stats: stats)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .id("bottom")
                }
            }
            .onAppear {
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "homeScrollToBottom") {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                #endif
            }
            }
            // Pulling down past the top shows more hero color, not a white gap.
            .background(alignment: .top) {
                Color.heroBackground.frame(height: 400).ignoresSafeArea()
            }
            .navigationTitle("Blocker") // shown as the back button on the Instagram/YouTube screens
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { stats.refresh() }
        }
    }
}

// MARK: - Hero

private struct Hero: View {
    @ObservedObject var stats: BlockStats

    private var sentence: String {
        stats.avoidedToday == 0
            ? "Every reel you skip is time back."
            : "That's \(BlockStats.timeSavedInWords(reels: stats.avoidedToday)) back."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Blocker")
                    .font(.system(size: 20, weight: .black).width(.expanded))
                Spacer()
                StreakSticker(days: stats.streak)
            }
            .padding(.top, 8)

            // The number, tilted like the icon's B, with the sticker on its shoulder.
            Text("\(stats.avoidedToday)")
                .font(.system(size: 230, weight: .black).width(.compressed))
                .tracking(-3)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .overlay(alignment: .topTrailing) {
                    NoPlaySticker()
                        .frame(width: 84, height: 84)
                        .rotationEffect(.degrees(10))
                        .offset(x: 52, y: 22)
                }
                .rotationEffect(.degrees(-6), anchor: .bottomLeading)
                .padding(.top, 4)
                .padding(.bottom, -62) // the line box has room for descenders the digits don't use

            Text(stats.avoidedToday == 1 ? "reel you didn't watch today" : "reels you didn't watch today")
                .font(.title3.weight(.bold))
            Text(sentence)
                .font(.title3)
            Text("\(stats.blockedToday) blocked, \(stats.hiddenToday) hidden in your feed")
                .font(.footnote.weight(.medium))
                .opacity(0.7)
                .padding(.top, 10)
        }
        .foregroundStyle(Color.heroInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .background(Color.heroBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stats.avoidedToday) reels you didn't watch today. \(sentence) \(stats.blockedToday) blocked, \(stats.hiddenToday) hidden in your feed. \(stats.streak) day streak.")
    }
}

/// The icon's red "no play" sign as a die-cut sticker.
private struct NoPlaySticker: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width
            ZStack {
                Circle().fill(.white)
                Circle()
                    .strokeBorder(Color.brandRed, lineWidth: size * 0.12)
                    .padding(size * 0.06)
                Triangle()
                    .fill(Color.brandInk)
                    .frame(width: size * 0.32, height: size * 0.36)
                    .offset(x: size * 0.03)
                Rectangle()
                    .fill(Color.brandRed)
                    .frame(width: size * 0.12, height: size * 0.78)
                    .rotationEffect(.degrees(-45))
            }
            .shadow(color: .black.opacity(0.18), radius: 0, x: 2, y: 3) // sticker edge, not a soft glow
        }
        .accessibilityHidden(true)
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}

private struct StreakSticker: View {
    let days: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text(days <= 1 ? "Day 1" : "\(days) days in a row")
        }
        .font(.subheadline.weight(.heavy))
        .foregroundStyle(Color.bandInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.bandBackground, in: Capsule())
        .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
        .rotationEffect(.degrees(4))
        .accessibilityHidden(true) // read as part of the hero
    }
}

// MARK: - Apps

private struct AppsBand: View {
    let rules: RulesFile

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                FilteredSiteView(title: "Instagram", site: .instagram, rules: rules.instagram)
            } label: {
                AppRow(name: "Instagram", detail: "Reels off")
            }
            Rectangle().fill(Color.bandInk.opacity(0.25)).frame(height: 1)
            NavigationLink {
                FilteredSiteView(title: "YouTube", site: .youtube, rules: rules.youtube)
            } label: {
                AppRow(name: "YouTube", detail: "Shorts off")
            }
        }
        .padding(.horizontal, 20)
        .background(Color.bandBackground)
    }
}

private struct AppRow: View {
    let name: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(.system(size: 30, weight: .black).width(.expanded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(detail)
                .font(.subheadline.weight(.semibold))
                .opacity(0.75)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(Color.bandInk)
        .padding(.vertical, 22)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(name) with \(detail.lowercased())")
    }
}

// MARK: - Week

/// Each day is a stack of film frames, one frame per `unit` reels. Tap a day to see its number.
/// When the week first scrolls into view, each stack runs up out of the baseline like a reel being
/// swiped and stops dead at its count, the days one after another, today last.
private struct FilmWeek: View {
    let days: [BlockStats.Day]
    @State private var selected: Date?
    @State private var fed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let maxFrames = 14
    /// Extra frames that run past before each stack stops.
    private static let runFrames = 8
    /// Frame height (10) plus spacing (3).
    private static let pitch: CGFloat = 13

    /// Reels per frame: 5, or more on heavy weeks so the tallest stack stays on screen.
    private var unit: Int {
        let most = days.map(\.total).max() ?? 0
        let needed = Int((Double(most) / Double(Self.maxFrames)).rounded(.up))
        return max(5, Int((Double(needed) / 5).rounded(.up)) * 5)
    }

    private var weekTotal: Int { days.reduce(0) { $0 + $1.total } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(.system(size: 22, weight: .black).width(.expanded))
                Spacer()
                Text(selectedText ?? "\(BlockStats.timeSaved(reels: weekTotal)) back")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    column(for: day, index: index)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = selected == day.date ? nil : day.date }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(dayName(day))
                        .accessibilityValue("\(day.total) reels")
                }
            }

            .background {
                // Run once the stacks are on screen above the tab bar, not while scrolled out of sight.
                GeometryReader { geometry in
                    let bottom = geometry.frame(in: .global).maxY
                    Color.clear
                        .onAppear { feedIfVisible(bottom) }
                        .onChange(of: bottom) { feedIfVisible($0) }
                }
            }

            Text("Each frame is \(unit) reels you didn't watch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            if reduceMotion { fed = true }
        }
    }

    private func feedIfVisible(_ bottom: CGFloat) {
        if !fed, bottom > 0, bottom < UIScreen.main.bounds.height - 100 {
            fed = true
        }
    }

    private var selectedText: String? {
        guard let selected, let day = days.first(where: { $0.date == selected }) else { return nil }
        return "\(dayName(day)): \(day.total) reels"
    }

    @ViewBuilder
    private func column(for day: BlockStats.Day, index: Int) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        let isSelected = selected == day.date
        let strong = isSelected || (selected == nil && isToday)
        let frames = day.total == 0 ? 0 : max(1, Int((Double(day.total) / Double(unit)).rounded()))
        let window = CGFloat(frames) * Self.pitch - 3
        let delay = Double(index) * 0.07
        VStack(spacing: 3) {
            Text("\(day.total)")
                .font(.caption.weight(.bold))
                .opacity(strong && day.total > 0 && fed ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2).delay(delay + 0.8), value: fed)
                .padding(.bottom, 3)
            if frames > 0 {
                // A strip longer than the stack, seen through a window the stack's size: it starts
                // below the baseline, runs up so the extra frames fly past and out the top, and stops
                // with exactly this day's frames showing.
                VStack(spacing: 3) {
                    ForEach(0..<(Self.runFrames + frames), id: \.self) { _ in
                        FilmFrame(strong: strong)
                    }
                }
                .fixedSize()
                .offset(y: fed ? -CGFloat(Self.runFrames) * Self.pitch : window + 3)
                .frame(height: window, alignment: .top)
                .clipped()
                .animation(reduceMotion ? nil : .timingCurve(0.1, 0.75, 0.2, 1, duration: 0.95).delay(delay), value: fed)
            }
            if frames == 0 {
                Rectangle().fill(Color(.separator)).frame(width: 26, height: 2)
            }
            Text(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(strong ? .bold : .regular))
                .foregroundStyle(strong ? .primary : .secondary)
                .fixedSize()
                .padding(.top, 6)
        }
    }

    private func dayName(_ day: BlockStats.Day) -> String {
        Calendar.current.isDateInToday(day.date) ? "Today" : day.date.formatted(.dateTime.weekday(.wide))
    }
}

/// One frame of film: a small cell with sprocket holes down both sides.
private struct FilmFrame: View {
    let strong: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(strong ? Color.chartToday : Color.chartPast)
            .frame(width: 28, height: 10)
            .overlay {
                HStack {
                    sprockets
                    Spacer()
                    sprockets
                }
                .padding(.horizontal, 2.5)
            }
    }

    private var sprockets: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 0.5).frame(width: 2.5, height: 2.5)
            RoundedRectangle(cornerRadius: 0.5).frame(width: 2.5, height: 2.5)
        }
        .foregroundStyle(Color(.systemBackground))
    }
}

// MARK: - Stickers

/// Milestones as a sticker sheet: earned ones stuck on at an angle, the rest as dashed outlines.
private struct StickerSheet: View {
    @ObservedObject var stats: BlockStats

    private struct Sticker: Identifiable {
        let title: String
        let systemImage: String
        let earned: Bool
        let tilt: Double
        var id: String { title }
    }

    private var stickers: [Sticker] {
        [
            Sticker(title: "First reel skipped", systemImage: "hand.raised.fill", earned: stats.totalAvoided >= 1, tilt: -7),
            Sticker(title: "100 skipped", systemImage: "trophy.fill", earned: stats.totalAvoided >= 100, tilt: 5),
            Sticker(title: "7 days in a row", systemImage: "flame.fill", earned: stats.streak >= 7, tilt: -3),
            Sticker(title: "1,000 skipped", systemImage: "crown.fill", earned: stats.totalAvoided >= 1000, tilt: 8),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stickers")
                .font(.system(size: 22, weight: .black).width(.expanded))
            HStack(alignment: .top, spacing: 8) {
                ForEach(stickers) { sticker in
                    VStack(spacing: 10) {
                        badge(for: sticker)
                            .frame(width: 64, height: 64)
                        Text(sticker.title)
                            .font(.caption.weight(sticker.earned ? .semibold : .regular))
                            .foregroundStyle(sticker.earned ? .primary : .tertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(sticker.title), \(sticker.earned ? "earned" : "not yet")")
                }
            }
        }
    }

    @ViewBuilder
    private func badge(for sticker: Sticker) -> some View {
        if sticker.earned {
            ZStack {
                Circle().fill(Color.brandYellow)
                Image(systemName: sticker.systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.brandInk)
            }
            .overlay(Circle().strokeBorder(.white, lineWidth: 3.5))
            .shadow(color: .black.opacity(0.18), radius: 0, x: 2, y: 3)
            .rotationEffect(.degrees(sticker.tilt))
        } else {
            ZStack {
                Circle().strokeBorder(Color(.tertiaryLabel), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
    }
}

#Preview {
    HomeView()
}
