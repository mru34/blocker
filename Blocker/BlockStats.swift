import Foundation

/// Reels avoided per day: reels blocked (taps, swipes, pages) plus reel posts hidden in the feed.
@MainActor
final class BlockStats: ObservableObject {
    static let shared = BlockStats()

    /// Rough watch time per reel, for the "time saved" estimate.
    static let secondsPerReel = 30

    struct Day: Identifiable {
        let date: Date
        let blocked: Int
        let hidden: Int
        var total: Int { blocked + hidden }
        var id: Date { date }
    }

    @Published private(set) var blockedToday = 0
    @Published private(set) var hiddenToday = 0
    /// The last 7 days, oldest first, ending with today.
    @Published private(set) var lastSevenDays: [Day] = []
    /// Every reel avoided since the app was installed.
    @Published private(set) var totalAvoided = 0
    /// Days in a row (ending today) the app was used.
    @Published private(set) var streak = 0

    var avoidedToday: Int { blockedToday + hiddenToday }

    private let defaults = UserDefaults.standard

    private let totalKey = "totalAvoided"
    private let activeDaysKey = "activeDays"

    private init() {
        // Older installs counted per day only: start the all-time total from what's on record.
        if defaults.object(forKey: totalKey) == nil {
            refresh()
            defaults.set(lastSevenDays.reduce(0) { $0 + $1.total }, forKey: totalKey)
        }
        refresh()
    }

    /// Call when the app comes to the foreground: today counts towards the streak.
    func recordActiveDay() {
        var days = Set(defaults.stringArray(forKey: activeDaysKey) ?? [])
        days.insert(key("day", Date()))
        // A streak only needs recent days; keep the list small.
        let recent = days.sorted().suffix(400)
        defaults.set(Array(recent), forKey: activeDaysKey)
        refresh()
    }

    func recordBlock() {
        add(1, to: "blocked")
    }

    func recordHidden(_ count: Int) {
        guard count > 0 else { return }
        add(count, to: "hidden")
    }

    /// Re-reads the counts, which also rolls over to a new day.
    func refresh() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        lastSevenDays = (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return Day(date: date,
                       blocked: defaults.integer(forKey: key("blocked", date)),
                       hidden: defaults.integer(forKey: key("hidden", date)))
        }
        blockedToday = lastSevenDays.last?.blocked ?? 0
        hiddenToday = lastSevenDays.last?.hidden ?? 0
        totalAvoided = defaults.integer(forKey: totalKey)

        let active = Set(defaults.stringArray(forKey: activeDaysKey) ?? [])
        var count = 0
        var date = today
        while active.contains(key("day", date)), let previous = calendar.date(byAdding: .day, value: -1, to: date) {
            count += 1
            date = previous
        }
        streak = count
    }

    /// "21 minutes", "1 hour 10 minutes": for sentences.
    static func timeSavedInWords(reels: Int) -> String {
        let minutes = reels * secondsPerReel / 60
        func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
        if minutes < 60 { return plural(minutes, "minute") }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? plural(hours, "hour") : "\(plural(hours, "hour")) \(plural(rest, "minute"))"
    }

    static func timeSaved(reels: Int) -> String {
        let minutes = reels * secondsPerReel / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    private func add(_ count: Int, to kind: String) {
        let todayKey = key(kind, Date())
        defaults.set(defaults.integer(forKey: todayKey) + count, forKey: todayKey)
        defaults.set(defaults.integer(forKey: totalKey) + count, forKey: totalKey)
        refresh()
    }

    // "blocked-2026-10-14": the blocked key format predates the hidden counts, so keep it.
    private func key(_ kind: String, _ date: Date) -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(kind)-\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }
}
