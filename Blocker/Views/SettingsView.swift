import SwiftUI

/// Settings in Home's language, kept quiet: wide black headings, plain rows with dividers,
/// status stickers for rule health, and the brand button for checking rules.
struct SettingsView: View {
    @ObservedObject private var rulesStore = RulesStore.shared
    @ObservedObject private var health = RuleHealth.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .black).width(.expanded))
                        .padding(.top, 8)

                    RuleHealthSection(rulesStore: rulesStore, health: health)
                    RulesSection(rulesStore: rulesStore)
                    #if DEBUG
                    DeveloperSection()
                    #endif
                    AboutSection()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct SectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 22, weight: .black).width(.expanded))
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Rule health

private struct RuleHealthSection: View {
    @ObservedObject var rulesStore: RulesStore
    @ObservedObject var health: RuleHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Rule health")
            RuleHealthRow(name: "Instagram", rules: rulesStore.rules.instagram, health: health)
            Divider()
            RuleHealthRow(name: "YouTube", rules: rulesStore.rules.youtube, health: health)
            Text(rulesStore.rules.healthReportURL == nil
                 ? "Checks today that the blocking rules still match each site. This stays on your phone."
                 : "Checks today that the blocking rules still match each site. Anonymous daily counts, with no account, links or names, help us notice when a site changes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }
}

private struct RuleHealthRow: View {
    let name: String
    let rules: SiteRules
    @ObservedObject var health: RuleHealth

    private enum Status {
        case notChecked, working, needsLook
    }

    var body: some View {
        let today = health.today(for: rules.domain)
        let warnings = health.warnings(for: rules)
        let status: Status = today.pageLoads == 0 ? .notChecked : (warnings.isEmpty ? .working : .needsLook)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(name)
                    .font(.headline)
                Spacer()
                StatusSticker(status: status)
            }
            Text(summary(today))
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(warnings) { warning in
                Text(warning.text)
                    .font(.footnote)
                    .foregroundStyle(Color.brandRed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func summary(_ today: RuleHealth.SiteDay) -> String {
        if today.pageLoads == 0 {
            return "Open \(name) in Blocker and this fills in."
        }
        if today.postsSeen > 0 {
            return "\(today.postsSeen) posts seen and \(today.reelsHidden) reels hidden today."
        }
        let ruleCount = rules.hideSelectors.count + rules.collapseSelectors.count
        return "\(today.matchedSelectors.count) of \(ruleCount) rules matched today."
    }

    private struct StatusSticker: View {
        let status: Status

        var body: some View {
            switch status {
            case .working:
                sticker("Working", systemImage: "checkmark", fill: .brandYellow, ink: .brandInk, tilt: -3)
            case .needsLook:
                sticker("Needs a look", systemImage: "exclamationmark", fill: .brandRed, ink: .white, tilt: 3)
            case .notChecked:
                Label("Not checked yet", systemImage: "clock")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().strokeBorder(Color(.tertiaryLabel), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
        }

        private func sticker(_ text: String, systemImage: String, fill: Color, ink: Color, tilt: Double) -> some View {
            Label(text, systemImage: systemImage)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(fill, in: Capsule())
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 0, x: 1.5, y: 2)
                .rotationEffect(.degrees(tilt))
        }
    }
}

// MARK: - Blocking rules

private struct RulesSection: View {
    @ObservedObject var rulesStore: RulesStore
    @State private var checking = false
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Blocking rules")
            row("Version", "\(rulesStore.rules.version)")
            Divider()
            row("Last checked", rulesStore.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "Not yet")

            Button {
                check()
            } label: {
                Text(checking ? "Checking…" : "Check for new rules")
                    .font(.headline)
                    .foregroundStyle(Color.bandInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.bandBackground, in: Capsule())
            }
            .padding(.top, 16)
            .disabled(checking || RulesStore.remoteURL == nil)

            Text(result ?? "Rules fix what gets hidden when Instagram or YouTube change, without an app update.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func check() {
        checking = true
        let before = rulesStore.rules.version
        let checkedBefore = rulesStore.lastUpdated
        Task {
            await rulesStore.refresh()
            checking = false
            if rulesStore.lastUpdated == checkedBefore {
                result = "Couldn't reach the rules server. Check your connection and try again."
            } else if rulesStore.rules.version != before {
                result = "Updated to version \(rulesStore.rules.version)."
            } else {
                result = "Up to date."
            }
        }
    }
}

// MARK: - Developer

#if DEBUG
private struct DeveloperSection: View {
    @AppStorage(Diagnostics.defaultsKey) private var diagnosticLogging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Developer")
            Toggle("Diagnostic logging", isOn: $diagnosticLogging)
                .tint(Color.bandBackground)
                .padding(.vertical, 14)
            Text("Logs page activity for debugging over the cable. Uses a little battery. Takes effect the next time you open Instagram or YouTube.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
#endif

// MARK: - About

private struct AboutSection: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        HStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.18), radius: 0, x: 2, y: 3)
                .rotationEffect(.degrees(-5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Blocker \(version)")
                    .font(.headline)
                Text("Keep the app, lose the scroll.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SettingsView()
}
