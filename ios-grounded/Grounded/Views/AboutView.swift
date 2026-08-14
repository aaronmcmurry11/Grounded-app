import SwiftUI

/// Legal document destinations.
///
/// These are placeholders. App Store and Play Store review both require a reachable privacy
/// policy URL, and a subscription would require reachable terms — so these must point at
/// published documents before the first submission, not at launch-day TODOs.
private enum LegalLinks {
    static let terms = URL(string: "https://grounded.app/legal/terms")
    static let privacy = URL(string: "https://grounded.app/legal/privacy")
    /// Flipped to false once the URLs above resolve to real published pages.
    static let arePlaceholders = true
}

/// About: build identity, the legal documents, and a reprint of what the user agreed to.
struct AboutView: View {
    @Environment(AppModel.self) private var appModel

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ZStack {
            AtmosphericBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    buildSection
                    legalSection
                    disclaimerSection
                    consentSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            BotanicalSprig(lineWidth: 1.1)
                .frame(width: 54, height: 74)
                .opacity(0.6)
            Text("Grounded")
                .heroDisplay(34)
                .foregroundStyle(Theme.cream)
            Text("Traditional, herbal and ancestral remedy knowledge — curated, cited, and plainly explained.")
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .padding(.top, 8)
    }

    // MARK: Build

    private var buildSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This build")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 14) {
                // Read from the bundle, never typed — a hand-written version string is wrong
                // the first time someone bumps the build and forgets this screen exists.
                stat("Version", version)
                Divider().overlay(Theme.hairline)
                stat("Build", build)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.86))
            Spacer(minLength: 10)
            Text(value)
                .uiLabel(15)
                .foregroundStyle(Theme.cream)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal")
                .sectionEyebrow()

            legalRow(title: "Terms of Service", url: LegalLinks.terms)
            legalRow(title: "Privacy Policy", url: LegalLinks.privacy)

            if LegalLinks.arePlaceholders {
                Text("Both links are placeholders and don't resolve yet. A reachable privacy policy is a hard requirement for App Store and Play Store review — these have to point at published documents before the first submission.")
                    .captionText(12, color: Theme.creamFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// A `Link` rather than a `SettingsRow`, so the row opens the document in the browser and
    /// carries the standard "leaves the app" affordance instead of a push chevron.
    private func legalRow(title: String, url: URL?) -> some View {
        Group {
            if let url {
                Link(destination: url) {
                    legalRowLabel(title: title)
                }
                .buttonStyle(SoftPressStyle(scale: 0.99))
            } else {
                legalRowLabel(title: title)
                    .opacity(0.5)
            }
        }
    }

    private func legalRowLabel(title: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .uiLabel(15)
                .foregroundStyle(Theme.cream)
            Spacer(minLength: 10)
            UIChromeIcon(systemName: "arrow.up.right", size: 12, color: Theme.creamFaint)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .contentShape(.rect)
    }

    // MARK: Disclaimer reprint

    /// The onboarding disclaimer, verbatim. Reprinted rather than paraphrased: it's the thing
    /// the user agreed to, and a shortened version here would quietly become a second,
    /// weaker disclaimer.
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The disclaimer you agreed to")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 12) {
                disclaimerRow("Grounded shares educational information drawn from a curated, cited source base.")
                disclaimerRow("It is not medical advice and does not diagnose, treat or replace care from a qualified professional.")
                disclaimerRow("Always speak with a clinician about your symptoms and any medication or supplement you take.")
                disclaimerRow("In an emergency, call 911 or your local emergency number.", emphasised: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
    }

    private func disclaimerRow(_ text: String, emphasised: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(emphasised ? Theme.safetyRed : Theme.creamFaint)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .bodyText(15)
                .foregroundStyle(emphasised ? Theme.cream : Theme.cream.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Consent record

    private var consentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your consent record")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 10) {
                Text(consentLine)
                    .bodyText(15)
                    .foregroundStyle(Theme.cream.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
                Text("You can withdraw consent and delete stored health data from Account → Privacy & data.")
                    .captionText(12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
    }

    /// Falls back to an undated statement for anyone who onboarded before the date was
    /// recorded — inventing a plausible date on a consent record would be worse than
    /// admitting it wasn't captured.
    private var consentLine: String {
        guard appModel.didConsentToHealthData else {
            return "Health-data collection consent is not currently on file."
        }
        guard let date = appModel.consentRecordedAt else {
            return "You agreed to health-data collection and confirmed you are 13 or older during onboarding. The exact date wasn't recorded on this device."
        }
        let formatted = date.formatted(.dateTime.month(.wide).day().year())
        return "You agreed to health-data collection and confirmed you are 13 or older on \(formatted)."
    }
}
