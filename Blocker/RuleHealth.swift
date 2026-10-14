import Foundation

/// Notices when Instagram or YouTube change their sites and our rules quietly stop working:
/// per site and day, how many feed posts were seen, how many reels got hidden, and which of our
/// selectors matched anything. Shown in Settings, and sent once a day as anonymous counts to
/// `RulesFile.healthReportURL` when the rules file sets one.
@MainActor
final class RuleHealth: ObservableObject {
    static let shared = RuleHealth()

    struct SiteDay: Codable, Equatable {
        var postsSeen = 0
        var reelsHidden = 0
        var pageLoads = 0
        var matchedSelectors: Set<String> = []
    }

    struct Warning: Identifiable {
        let text: String
        var id: String { text }
    }

    /// Day ("2026-10-14") → site domain → counts. Keeps the last 7 days.
    @Published private(set) var days: [String: [String: SiteDay]] = [:]

    private let defaults = UserDefaults.standard
    private let storageKey = "ruleHealth"
    private let lastSentKey = "ruleHealthLastSent"

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String: [String: SiteDay]].self, from: data) {
            days = saved
        }
    }

    func today(for domain: String) -> SiteDay {
        days[Self.dayString(Date())]?[domain] ?? SiteDay()
    }

    func record(domain: String, posts: Int = 0, hidden: Int = 0, pageLoads: Int = 0, matched: [String] = []) {
        let day = Self.dayString(Date())
        var site = days[day]?[domain] ?? SiteDay()
        site.postsSeen += posts
        site.reelsHidden += hidden
        site.pageLoads += pageLoads
        site.matchedSelectors.formUnion(matched)
        days[day, default: [:]][domain] = site
        // Keep a week.
        let cutoff = Self.dayString(Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        days = days.filter { $0.key > cutoff }
        if let data = try? JSONEncoder().encode(days) {
            defaults.set(data, forKey: storageKey)
        }
    }

    /// Signs that a rule stopped working today. Needs some browsing first, so a quick look
    /// doesn't raise false alarms.
    func warnings(for rules: SiteRules) -> [Warning] {
        let site = today(for: rules.domain)
        var warnings: [Warning] = []
        if !rules.collapseSelectors.isEmpty, site.postsSeen >= 40, site.reelsHidden == 0 {
            warnings.append(Warning(text: "No reels hidden in \(site.postsSeen) feed posts today. \(rules.domain) may have changed, so the feed rules need checking."))
        }
        if site.pageLoads >= 3 {
            for selector in rules.hideSelectors where !site.matchedSelectors.contains(selector) {
                warnings.append(Warning(text: "“\(selector)” hasn't matched anything today."))
            }
        }
        return warnings
    }

    /// Sends finished days (not today) to the health endpoint, once each.
    func sendReports(to url: URL?, rulesVersion: Int) async {
        guard let url else { return }
        let today = Self.dayString(Date())
        let lastSent = defaults.string(forKey: lastSentKey) ?? ""
        for day in days.keys.sorted() where day < today && day > lastSent {
            let report = Report(
                date: day,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
                rulesVersion: rulesVersion,
                sites: (days[day] ?? [:]).mapValues { site in
                    Report.Site(postsSeen: site.postsSeen, reelsHidden: site.reelsHidden,
                                pageLoads: site.pageLoads, matchedSelectors: site.matchedSelectors.sorted())
                }
            )
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(report)
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200
            else {
                Diagnostics.log("[health] report for \(day) failed, will retry next launch")
                return
            }
            defaults.set(day, forKey: lastSentKey)
            Diagnostics.log("[health] sent report for \(day)")
        }
    }

    /// Anonymous: counts and our own selectors only, no account, link or device ID.
    private struct Report: Encodable {
        struct Site: Encodable {
            let postsSeen: Int
            let reelsHidden: Int
            let pageLoads: Int
            let matchedSelectors: [String]
        }
        let date: String
        let appVersion: String
        let rulesVersion: Int
        let sites: [String: Site]
    }

    private static func dayString(_ date: Date) -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }
}
