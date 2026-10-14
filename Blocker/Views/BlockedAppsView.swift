import SwiftUI

/// Preview of the Screen Time lock (Phase 5, needs the paid developer account): the screen people
/// will see when they open the real Instagram, and how the flow will go. Its button already works,
/// so the demo can walk the whole path today.
struct BlockedAppsView: View {
    @ObservedObject private var rulesStore = RulesStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("Blocked apps")
                        .font(.system(size: 30, weight: .black).width(.expanded))
                        .padding(.top, 8)

                    LockScreenPreview(rules: rulesStore.rules)
                        .frame(maxWidth: .infinity)

                    Steps()
                    AppsToLock()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Blocked apps") // shown as the back button on the Instagram screen
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - The lock screen

/// What the real Instagram will show once it's locked, drawn as a small phone screen.
private struct LockScreenPreview: View {
    let rules: RulesFile

    var body: some View {
        VStack(spacing: 0) {
            Image("Logo")
                .resizable()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white, lineWidth: 3.5))
                .shadow(color: .black.opacity(0.18), radius: 0, x: 2, y: 3)
                .rotationEffect(.degrees(-4))
                .padding(.top, 44)

            Text("Instagram\nis locked")
                .font(.system(size: 40, weight: .black).width(.compressed))
                .multilineTextAlignment(.center)
                .lineSpacing(-6)
                .padding(.top, 22)

            Text("The reels live in there.\nYour DMs work in Blocker.")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .opacity(0.75)
                .padding(.top, 10)

            Spacer(minLength: 28)

            NavigationLink {
                FilteredSiteView(title: "Instagram", site: .instagram, rules: rules.instagram)
            } label: {
                Text("Open without reels")
                    .font(.headline)
                    .foregroundStyle(Color.brandYellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.brandInk, in: Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
        }
        .foregroundStyle(Color.brandInk)
        .frame(width: 250, height: 410)
        .background(Color.brandYellow, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(Color.primary, lineWidth: 6))
        .overlay(alignment: .topTrailing) {
            Text("Coming soon")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.brandRed, in: Capsule())
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.18), radius: 0, x: 2, y: 3)
                .rotationEffect(.degrees(9))
                .offset(x: 30, y: 26)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview of the lock screen, coming soon")
    }
}

// MARK: - How it'll work

private struct Steps: View {
    private let steps = [
        "Tap the real Instagram app, like always.",
        "It's locked, and shows the screen above instead.",
        "One tap and you're in Instagram without reels.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How it'll work")
                .font(.system(size: 22, weight: .black).width(.expanded))
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.system(size: 28, weight: .black).width(.compressed))
                        .frame(width: 18, alignment: .leading)
                    Text(step)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Apps

private struct AppsToLock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Apps to lock")
                .font(.system(size: 22, weight: .black).width(.expanded))
                .padding(.bottom, 6)
            row("Instagram")
            Divider()
            row("YouTube")
            Text("Locking other apps uses Apple's Screen Time, which arrives in the next version of Blocker.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }

    private func row(_ name: String) -> some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundStyle(.tertiary)
            Text(name)
                .font(.headline)
            Spacer()
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    BlockedAppsView()
}
