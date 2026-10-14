import Foundation

/// Counts blocked reels / Shorts / Explore pages per day.
@MainActor
final class BlockStats: ObservableObject {
    static let shared = BlockStats()

    @Published private(set) var blockedToday = 0

    private let defaults = UserDefaults.standard

    private init() {
        refresh()
    }

    func recordBlock() {
        refresh()
        blockedToday += 1
        defaults.set(blockedToday, forKey: todayKey)
    }

    /// Re-reads today's count, which resets it when the day changes.
    func refresh() {
        blockedToday = defaults.integer(forKey: todayKey)
    }

    private var todayKey: String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "blocked-\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }
}
