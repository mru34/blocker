import Foundation

/// The whole rules file: bundled as rules.json and fetched from our server by RulesStore.
struct RulesFile: Codable, Equatable {
    var version: Int
    var instagram: SiteRules
    var youtube: SiteRules
}

/// What to block on one site. Only homeURL is required in the JSON; everything else defaults to empty.
struct SiteRules: Codable, Equatable {
    var homeURL: URL
    /// A page is blocked if its path contains any of these...
    var blockedPaths: [String]
    /// ...unless it starts with one of these.
    var allowedPaths: [String]
    /// Exact paths sent somewhere else instead of being blocked outright.
    var redirects: [String: String]
    /// CSS selectors hidden on every page.
    var hideSelectors: [String]
    /// Feed items shrunk to a slim "Reel hidden" bar. Hiding them completely (zero height)
    /// breaks Instagram's feed, which only draws posts near the screen and stops loading.
    var collapseSelectors: [String]
    /// Pause any video that starts playing, except on these paths. Nil means videos are fine.
    var videoAllowedPaths: [String]?
    /// Clicked when a blocked video plays in a full-screen viewer (e.g. a reel opened from DMs).
    var viewerCloseSelector: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeURL = try container.decode(URL.self, forKey: .homeURL)
        blockedPaths = try container.decodeIfPresent([String].self, forKey: .blockedPaths) ?? []
        allowedPaths = try container.decodeIfPresent([String].self, forKey: .allowedPaths) ?? []
        redirects = try container.decodeIfPresent([String: String].self, forKey: .redirects) ?? [:]
        hideSelectors = try container.decodeIfPresent([String].self, forKey: .hideSelectors) ?? []
        collapseSelectors = try container.decodeIfPresent([String].self, forKey: .collapseSelectors) ?? []
        videoAllowedPaths = try container.decodeIfPresent([String].self, forKey: .videoAllowedPaths)
        viewerCloseSelector = try container.decodeIfPresent(String.self, forKey: .viewerCloseSelector)
    }

    func isBlocked(path: String) -> Bool {
        if allowedPaths.contains(where: { path.hasPrefix($0) }) { return false }
        return blockedPaths.contains(where: { path.contains($0) })
    }

    /// "instagram.com" for "https://www.instagram.com/", so www., m. and bare hosts all match.
    var domain: String {
        let host = homeURL.host ?? ""
        for prefix in ["www.", "m."] where host.hasPrefix(prefix) {
            return String(host.dropFirst(prefix.count))
        }
        return host
    }

    func matches(host: String?) -> Bool {
        guard let host else { return false }
        return host == domain || host.hasSuffix("." + domain)
    }
}
