import Foundation

/// Keeps the blocking rules up to date without an App Store release:
/// fetches rules.json from our server, caches it on disk, and falls back to the
/// cached or bundled copy when offline or when the server file is broken.
@MainActor
final class RulesStore: ObservableObject {
    static let shared = RulesStore()

    /// The live rules file. Edit it there to change what's blocked; nil skips fetching.
    static let remoteURL = URL(string: "https://gist.githubusercontent.com/mru34/ec1e1901fa70002ad416e64183d6cd2b/raw/rules.json")

    @Published private(set) var rules: RulesFile
    @Published private(set) var lastUpdated: Date?

    private let cacheURL = URL.applicationSupportDirectory.appending(path: "rules.json")

    private init() {
        let cached = Self.decode(contentsOf: cacheURL)
        // After an app update the bundled copy may be newer than the cache.
        if let cached, cached.version >= Self.bundled.version {
            rules = cached
        } else {
            rules = Self.bundled
        }
    }

    func refresh() async {
        guard let remoteURL = Self.remoteURL else { return }
        let request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            // Decode before caching so a broken server file never replaces working rules.
            let fresh = try JSONDecoder().decode(RulesFile.self, from: data)
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: cacheURL, options: .atomic)
            lastUpdated = Date()
            log("fetched rules version \(fresh.version)\(fresh == rules ? " (unchanged)" : ", applying")")
            if fresh != rules {
                rules = fresh
            }
        } catch {
            // Offline or a bad file on the server: keep the rules we have.
            log("rules fetch failed, keeping version \(rules.version): \(error)")
        }
    }

    private func log(_ text: String) {
        #if DEBUG
        fputs("[rules] \(text)\n", stderr)
        #endif
    }

    private static let bundled: RulesFile = {
        guard let url = Bundle.main.url(forResource: "rules", withExtension: "json"),
              let rules = decode(contentsOf: url)
        else {
            fatalError("rules.json is missing from the app or isn't valid")
        }
        return rules
    }()

    private static func decode(contentsOf url: URL) -> RulesFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RulesFile.self, from: data)
    }
}
