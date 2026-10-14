import Foundation

/// Diagnostic logging for debug builds: page events (debug.js) and rule fetches, written to the
/// console that `devicectl device process launch --console` shows. Off by default because debug.js
/// checks the page every few seconds. Turn it on in Settings, or launch with `-diagnosticLogging YES`.
enum Diagnostics {
    static let defaultsKey = "diagnosticLogging"

    static var isEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: defaultsKey)
        #else
        false
        #endif
    }

    static func log(_ text: String) {
        guard isEnabled else { return }
        fputs(text + "\n", stderr)
    }
}
