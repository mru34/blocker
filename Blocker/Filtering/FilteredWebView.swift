import SwiftUI
import WebKit

/// Full-screen filtered site, pushed from the Home tab.
struct FilteredSiteView: View {
    let title: String
    let rules: SiteRules

    @State private var handle = WebViewHandle()

    var body: some View {
        FilteredWebView(rules: rules, handle: handle)
            .ignoresSafeArea(.container, edges: .bottom) // not .keyboard: the page must shrink so the DM text box stays visible
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Reload")
                }
            }
    }

    // Instagram's story composer can hang after "Share story"; reloading it just hangs again,
    // so from a create screen go back to the feed instead.
    private func reload() {
        guard let webView = handle.webView else { return }
        if webView.url?.path.hasPrefix("/create") == true {
            webView.load(URLRequest(url: rules.homeURL))
        } else {
            webView.reload()
        }
    }
}

/// Lets the SwiftUI toolbar reach the web view.
final class WebViewHandle {
    weak var webView: WKWebView?
}

struct FilteredWebView: UIViewRepresentable {
    let rules: SiteRules
    var handle: WebViewHandle?

    // Look like iPhone Safari so Instagram serves its normal mobile site.
    private static let safariUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

    private static let messageHandlerName = "blocker"
    private static let debugHandlerName = "blockerDebug"

    func makeCoordinator() -> Coordinator {
        Coordinator(rules: rules)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // keeps the login cookie across app launches
        config.allowsInlineMediaPlayback = true

        let contentController = config.userContentController
        Self.installScripts(for: rules, into: contentController)
        contentController.add(context.coordinator, name: Self.messageHandlerName)
        #if DEBUG
        contentController.add(context.coordinator, name: Self.debugHandlerName)
        #endif

        let webView = WKWebView(frame: .zero, configuration: config)
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true // lets Safari's Web Inspector on the Mac attach
        }
        #endif
        webView.customUserAgent = Self.safariUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: rules.homeURL))
        handle?.webView = webView
        return webView
    }

    // New rules arrived from the server while this screen is open: re-inject and reload.
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.rules != rules else { return }
        context.coordinator.rules = rules
        let contentController = webView.configuration.userContentController
        contentController.removeAllUserScripts()
        Self.installScripts(for: rules, into: contentController)
        webView.reload()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: messageHandlerName)
        #if DEBUG
        webView.configuration.userContentController.removeScriptMessageHandler(forName: debugHandlerName)
        #endif
    }

    private static func installScripts(for rules: SiteRules, into contentController: WKUserContentController) {
        contentController.addUserScript(WKUserScript(
            source: filterScript(for: rules),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        #if DEBUG
        if let url = Bundle.main.url(forResource: "debug", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            contentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        #endif
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

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var rules: SiteRules

        init(rules: SiteRules) {
            self.rules = rules
        }

        // Full page loads. In-app (pushState) navigation is handled by filter.js.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard action.targetFrame?.isMainFrame == true,
                  let url = action.request.url,
                  rules.matches(host: url.host),
                  let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path // keeps the trailing slash
            else { return .allow }

            debugLog("navigation \(url.absoluteString)")

            if let target = rules.redirects[path], let redirect = URL(string: target, relativeTo: url) {
                DispatchQueue.main.async { webView.load(URLRequest(url: redirect)) }
                return .cancel
            }
            if rules.isBlocked(path: path) {
                BlockStats.shared.recordBlock()
                return .cancel
            }
            return .allow
        }

        // Links that open a new window (target="_blank") load in this web view instead,
        // so they still go through the policy check above.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.targetFrame == nil {
                webView.load(action.request)
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == FilteredWebView.debugHandlerName {
                debugLog("\(message.body)")
            } else if message.body as? String == "blocked" {
                debugLog("blocked by filter.js")
                BlockStats.shared.recordBlock()
            }
        }

        private func debugLog(_ text: String) {
            #if DEBUG
            fputs("[\(rules.domain)] \(text)\n", stderr)
            #endif
        }
    }
}
