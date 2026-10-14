import SwiftUI
import WebKit

enum Site: String {
    case instagram, youtube

    func rules(in file: RulesFile) -> SiteRules {
        switch self {
        case .instagram: file.instagram
        case .youtube: file.youtube
        }
    }
}

/// Full-screen filtered site, pushed from the Home tab.
struct FilteredSiteView: View {
    let title: String
    let site: Site
    let rules: SiteRules

    var body: some View {
        let session = SiteSession.shared(site, rules: rules)
        FilteredWebView(session: session, rules: rules)
            .ignoresSafeArea(.container, edges: .bottom) // not .keyboard: the page must shrink so the DM text box stays visible
            .overlay { LoadingScreen(session: session, siteName: title, blockedThing: site == .youtube ? "Shorts" : "Reels") }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Reload")
                }
            }
            .onAppear { session.willShow() }
            .onDisappear { session.didHide() }
    }
}

/// Brand screen shown while a site loads, instead of a blank white page.
private struct LoadingScreen: View {
    @ObservedObject var session: SiteSession
    let siteName: String
    let blockedThing: String

    var body: some View {
        ZStack {
            if !session.isReady {
                ZStack {
                    Color.brandYellow.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image("Logo")
                            .resizable()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                        VStack(spacing: 4) {
                            Text("Loading \(siteName)")
                                .font(.headline)
                            Text("\(blockedThing) not included.")
                                .font(.subheadline)
                                .opacity(0.7)
                        }
                        .foregroundStyle(Color.brandInk)
                        ProgressView(value: max(session.progress, 0.05))
                            .tint(.brandInk)
                            .frame(width: 160)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: session.isReady)
        .allowsHitTesting(!session.isReady)
    }
}

/// Shows a site's long-lived web view; the web view itself belongs to its SiteSession.
struct FilteredWebView: UIViewRepresentable {
    let session: SiteSession
    let rules: SiteRules

    func makeUIView(context: Context) -> WKWebView {
        session.webView
    }

    // New rules arrived from the server while this screen is open.
    func updateUIView(_ webView: WKWebView, context: Context) {
        session.update(rules: rules)
    }
}

/// One web view per site that lives as long as the app, so leaving Instagram and coming back is
/// instant (the site itself takes ~10 s to load) and it can be preloaded when the app starts.
@MainActor
final class SiteSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private static var sessions: [Site: SiteSession] = [:]

    static func shared(_ site: Site, rules: SiteRules) -> SiteSession {
        if let session = sessions[site] {
            session.update(rules: rules)
            return session
        }
        let session = SiteSession(rules: rules)
        sessions[site] = session
        return session
    }

    /// Starts loading a site in the background so it's ready when the user opens it.
    static func preload(_ site: Site, rules: SiteRules) {
        _ = shared(site, rules: rules)
    }

    // Look like iPhone Safari so Instagram serves its normal mobile site.
    private static let safariUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

    private static let messageHandlerName = "blocker"
    private static let debugHandlerName = "blockerDebug"

    /// After this long out of sight, reopening reloads the page so the feed isn't stale.
    private static let staleAfter: TimeInterval = 30 * 60

    /// The loading screen never stays up longer than this once the user is looking at it;
    /// after that the site's own loading animation takes over.
    private static let maxLoadingScreen: TimeInterval = 2

    let webView: WKWebView
    private(set) var rules: SiteRules
    private let createdAt = Date()
    private var loggedFirstLoad = false
    private var hiddenSince: Date?

    /// False while a page load is under way and the site hasn't shown real content yet
    /// (filter.js says when, via the site's readySelector). Drives the loading screen.
    @Published private(set) var isReady = false
    @Published private(set) var progress: Double = 0
    private var progressObservation: NSKeyValueObservation?
    private var loadID = 0

    private static let haptic = UIImpactFeedbackGenerator(style: .rigid)

    private init(rules: SiteRules) {
        self.rules = rules

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // keeps the login cookie across app launches
        config.allowsInlineMediaPlayback = true
        Self.installScripts(for: rules, into: config.userContentController)

        // A phone-sized frame, so a preloaded page lays out like it will be shown.
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 393, height: 852), configuration: config)
        super.init()

        // The content controller keeps this session alive; sessions live as long as the app anyway.
        config.userContentController.add(self, name: Self.messageHandlerName)
        #if DEBUG
        config.userContentController.add(self, name: Self.debugHandlerName)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true // lets Safari's Web Inspector on the Mac attach
        }
        #endif
        webView.customUserAgent = Self.safariUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        progressObservation = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
            let progress = webView.estimatedProgress
            Task { @MainActor in self?.progress = progress }
        }
        beginLoading()
        webView.load(URLRequest(url: rules.homeURL))
    }

    /// Every full load we start shows the loading screen until the page is ready.
    private func beginLoading() {
        loadID += 1
        isReady = false
        if hiddenSince == nil, webView.window != nil {
            capLoadingScreen()
        }
    }

    private func markReady() {
        guard !isReady else { return }
        isReady = true
    }

    /// New rules from the server: re-inject them and reload.
    func update(rules newRules: SiteRules) {
        guard newRules != rules else { return }
        rules = newRules
        let contentController = webView.configuration.userContentController
        contentController.removeAllUserScripts()
        Self.installScripts(for: newRules, into: contentController)
        beginLoading()
        webView.reload()
    }

    // Instagram's story composer can hang after "Share story"; reloading it just hangs again,
    // so from a create screen go back to the feed instead.
    func reload() {
        beginLoading()
        if webView.url?.path.hasPrefix("/create") == true {
            webView.load(URLRequest(url: rules.homeURL))
        } else {
            webView.reload()
        }
    }

    func willShow() {
        if let hiddenSince, Date().timeIntervalSince(hiddenSince) > Self.staleAfter {
            debugLog("hidden for over 30 min, reloading")
            beginLoading()
            webView.reload()
        }
        hiddenSince = nil
        capLoadingScreen()
    }

    private func capLoadingScreen() {
        guard !isReady else { return }
        let load = loadID
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxLoadingScreen) { [weak self] in
            guard let self, self.loadID == load else { return }
            self.markReady()
        }
    }

    func didHide() {
        hiddenSince = Date()
    }

    private static func installScripts(for rules: SiteRules, into contentController: WKUserContentController) {
        if !Diagnostics.isFilterDisabled {
            contentController.addUserScript(WKUserScript(
                source: filterScript(for: rules),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }
        if Diagnostics.isEnabled,
           let url = Bundle.main.url(forResource: "debug", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            contentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
    }

    private static func filterScript(for rules: SiteRules) -> String {
        guard let url = Bundle.main.url(forResource: "filter", withExtension: "js"),
              let template = try? String(contentsOf: url, encoding: .utf8),
              let data = try? JSONEncoder().encode(rules),
              let json = String(data: data, encoding: .utf8)
        else {
            assertionFailure("filter.js missing from the app bundle")
            return ""
        }
        return template.replacingOccurrences(of: "__BLOCKER_RULES__", with: json)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        RuleHealth.shared.record(domain: rules.domain, pageLoads: 1)
        // If filter.js never says the page is ready (e.g. readySelector no longer matches),
        // don't keep the loading screen up for long.
        let load = loadID
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.loadID == load else { return }
            self.markReady()
        }

        guard !loggedFirstLoad else { return }
        loggedFirstLoad = true
        let ms = Int(Date().timeIntervalSince(createdAt) * 1000)
        debugLog("speed: page finished loading \(ms) ms after the web view was created\(Diagnostics.isFilterDisabled ? " (filter OFF)" : "")")
    }

    // Full page loads. In-app (pushState) navigation is handled by filter.js.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard action.targetFrame?.isMainFrame == true, let url = action.request.url else { return .allow }

        // Other websites (a link in someone's bio, mailto:, ...) open in Safari or their own app,
        // instead of trapping the user inside this screen.
        let scheme = url.scheme?.lowercased() ?? ""
        let isWeb = scheme == "http" || scheme == "https"
        if (isWeb && !rules.isInternal(host: url.host)) || (!isWeb && !["about", "blob", "data"].contains(scheme)) {
            debugLog("opening outside the app: \(url.absoluteString)")
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return .cancel
        }

        guard rules.matches(host: url.host),
              let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path // keeps the trailing slash
        else { return .allow }

        debugLog("navigation \(url.absoluteString)")

        if let target = rules.redirects[path], let redirect = URL(string: target, relativeTo: url) {
            DispatchQueue.main.async { webView.load(URLRequest(url: redirect)) }
            return .cancel
        }
        if rules.isBlocked(path: path) {
            BlockStats.shared.recordBlock()
            Self.haptic.impactOccurred()
            webView.evaluateJavaScript("window.__blockerToast && window.__blockerToast()", completionHandler: nil)
            return .cancel
        }
        return .allow
    }

    // iOS may kill the page's process to free memory while the app is in the background,
    // which leaves a blank white screen. Load it again.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        debugLog("web content process ended, reloading")
        beginLoading()
        if webView.url != nil {
            webView.reload()
        } else {
            webView.load(URLRequest(url: rules.homeURL))
        }
    }

    // MARK: - WKUIDelegate

    // Links that open a new window (target="_blank") load in this web view instead,
    // so they still go through the policy check above.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil {
            webView.load(action.request)
        }
        return nil
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == Self.debugHandlerName {
            debugLog("\(message.body)")
            return
        }
        guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
        switch event {
        case "blocked":
            Self.haptic.impactOccurred()
            if body["counted"] as? Bool == true {
                debugLog("blocked by filter.js")
                BlockStats.shared.recordBlock()
            }
        case "ready":
            markReady()
        case "stats":
            let posts = body["posts"] as? Int ?? 0
            let hidden = body["hidden"] as? Int ?? 0
            let matched = body["matched"] as? [String] ?? []
            BlockStats.shared.recordHidden(hidden)
            RuleHealth.shared.record(domain: rules.domain, posts: posts, hidden: hidden, matched: matched)
            debugLog("stats: +\(posts) posts, +\(hidden) reels hidden, matched \(matched)")
        default:
            break
        }
    }

    private func debugLog(_ text: String) {
        Diagnostics.log("[\(rules.domain)] \(text)")
    }
}
