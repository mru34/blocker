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
    /// Videos inside these elements may play (normal feed posts), unless the post is collapsed.
    var videoAllowedIn: [String]
    /// On these paths (DM threads) the one reel the user taps may play; swiping to the next is blocked.
    var singleVideoPaths: [String]
    /// Clicked when a blocked video plays in a full-screen viewer (e.g. a reel opened from DMs).
    var viewerCloseSelector: String?
    /// Other sites that stay inside this screen, such as login pages. Everything else opens in Safari.
    var allowedHosts: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeURL = try container.decode(URL.self, forKey: .homeURL)
        // Drop empty entries: every path "contains" "", so one stray "" would block the whole site.
        blockedPaths = (try container.decodeIfPresent([String].self, forKey: .blockedPaths) ?? []).filter { !$0.isEmpty }
        allowedPaths = (try container.decodeIfPresent([String].self, forKey: .allowedPaths) ?? []).filter { !$0.isEmpty }
        redirects = try container.decodeIfPresent([String: String].self, forKey: .redirects) ?? [:]
        hideSelectors = try container.decodeIfPresent([String].self, forKey: .hideSelectors) ?? []
        collapseSelectors = try container.decodeIfPresent([String].self, forKey: .collapseSelectors) ?? []
        videoAllowedPaths = try container.decodeIfPresent([String].self, forKey: .videoAllowedPaths)
        videoAllowedIn = try container.decodeIfPresent([String].self, forKey: .videoAllowedIn) ?? []
        singleVideoPaths = (try container.decodeIfPresent([String].self, forKey: .singleVideoPaths) ?? []).filter { !$0.isEmpty }
        viewerCloseSelector = try container.decodeIfPresent(String.self, forKey: .viewerCloseSelector)
        allowedHosts = try container.decodeIfPresent([String].self, forKey: .allowedHosts) ?? []
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

    /// The site itself or one of its allowedHosts (subdomains included).
    func isInternal(host: String?) -> Bool {
        guard let host else { return false }
        return matches(host: host) || allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
