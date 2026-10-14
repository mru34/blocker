import Foundation

/// What to block on one site. Phase 3 will fetch these from our server; for now they're bundled.
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

extension SiteRules {
    // Selectors are starting guesses: check them against the live sites in Safari's Web Inspector.
    static let instagram = SiteRules(
        homeURL: URL(string: "https://www.instagram.com/")!,
        blockedPaths: ["/reels/", "/reel/", "/explore/"],
        // Search lives under /explore/search/, so keep it reachable.
        allowedPaths: ["/explore/search"],
        // The Explore tab goes straight to search instead of the reels grid.
        redirects: ["/explore/": "/explore/search/", "/explore": "/explore/search/"],
        hideSelectors: [
            "a[href*='/reels/']",
        ],
        // Every Instagram video is a reel now, so video posts go too.
        collapseSelectors: [
            "article:has(a[href*='/reel/'])",
            "article:has(video)",
        ],
        videoAllowedPaths: ["/stories/"],
        viewerCloseSelector: "svg[aria-label='Close']"
    )

    static let youtube = SiteRules(
        homeURL: URL(string: "https://m.youtube.com/")!,
        blockedPaths: ["/shorts"],
        allowedPaths: [],
        redirects: [:],
        hideSelectors: [
            "ytm-reel-shelf-renderer",
            "ytm-shorts-lockup-view-model",
            "ytm-rich-section-renderer:has(ytm-shorts-lockup-view-model)",
            "a[href^='/shorts']",
            "ytm-pivot-bar-item-renderer:has(.pivot-shorts)",
        ],
        collapseSelectors: [],
        videoAllowedPaths: nil,
        viewerCloseSelector: nil
    )
}
