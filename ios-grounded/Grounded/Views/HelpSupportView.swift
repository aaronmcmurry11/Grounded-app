import SwiftUI

/// Help & Support. The FAQ answers the questions people actually arrive with — including the
/// two that are uncomfortable to answer honestly ("is this medical advice", "how do you
/// decide what goes in") — and the screen states plainly which parts of the app are still
/// illustrative rather than real.
struct HelpSupportView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RemedyLibrary.self) private var library

    @State private var isReporting = false

    private var queuedReports: Int { appModel.issueReports.count }

    var body: some View {
        ZStack {
            AtmosphericBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    faqSection
                    scannerSection
                    reportSection
                    previewSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $isReporting) {
            ReportIssueView(remedy: nil)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Help & support")
                .sectionEyebrow(13, color: Theme.cream.opacity(0.7))
            Text("Straight answers")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)
            Text("What Grounded is, what it isn't, and what's still unfinished. Where an answer is unflattering, it's written that way on purpose.")
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.85))
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
        .overlay(alignment: .topTrailing) {
            BotanicalSprig(lineWidth: 1)
                .frame(width: 52, height: 74)
                .opacity(0.28)
                .padding(16)
        }
        .padding(.top, 8)
    }

    // MARK: FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common questions")
                .sectionEyebrow()

            // The hardest question is expanded on arrival. Leaving "is this medical advice"
            // collapsed would technically answer it while functionally hiding it.
            ExpandableRow(title: "Is this medical advice?", isInitiallyExpanded: true) {
                answer("No. Grounded is educational. Every entry describes what a remedy has traditionally been used for and what evidence sits behind that use — it does not diagnose you, does not tell you what to take, and does not replace a clinician.")
                answer("Nothing here is personalised to you. The app doesn't know your conditions, your medication, or your history, so it can't reason about interactions in your case. A clinician or pharmacist can.")
                emergencyLine
            }

            ExpandableRow(title: "How do you choose what goes in the Apothecary?") {
                answer("An entry has to be documented in a source we can name. In practice that means a regulatory herbal monograph — NCCIH, the EMA's herbal committee, Health Canada's natural-health database — or a peer-reviewed human study.")
                answer("Popularity isn't a criterion. A remedy that everyone has heard of but that has no evidence behind it either stays at Traditional use or doesn't go in at all.")
                answer("Study funding is checked. Where a positive trial was paid for or supplied by a manufacturer of the tested product, that's recorded on the entry and weighed against independent reviews — and it has already moved at least one entry down a tier.")
                answer("The library is currently \(library.remedies.count) entries. It's deliberately small: every entry is written from primary sources by hand, and breadth would come at the cost of that.")
            }

            ExpandableRow(title: "What do the evidence tiers actually mean?") {
                answer("A tier describes the *kind* of evidence behind a remedy, not how strong it is. Clinical tier means at least one peer-reviewed human study exists — it does not mean the effect is large, reliable, or settled.")
                answer("The third tier in the design, herbalist-reviewed, has no content behind it. No practitioner reviews entries today, and the sourcing screen says so rather than quietly hiding the tier.")
            }

            ExpandableRow(title: "Where does the chat's information come from?") {
                answer("The chat can only cite entries from the bundled library, and remedy cards appear only for entries it returns as a genuine match. It's a language model, so it can still be wrong in its wording — the entry it points to is the authoritative part, not the sentence around it.")
                answer("It is not a triage system. It doesn't detect emergencies and doesn't decide whether your symptoms are serious.")
            }

            ExpandableRow(title: "What happens to my data?") {
                answer("Saved remedies, the topics you ask about and your scan history stay on this device. You can see exactly what's stored, and delete any of it, in Account → Privacy & data.")
                answer("Grounded doesn't send push notifications yet. The update toggles control what appears in the Updates inbox, nothing more.")
            }
        }
    }

    private func answer(_ text: String) -> some View {
        Text(text)
            .bodyText(15)
            .foregroundStyle(Theme.cream.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emergencyLine: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Theme.safetyRed)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text("In an emergency, call 911 or your local emergency number.")
                .bodyText(15)
                .foregroundStyle(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Scanner honesty

    private var scannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About the scanner")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 12) {
                Text("The barcode scanner is illustrative only")
                    .uiLabel(15)
                    .foregroundStyle(Theme.cream)
                    .fixedSize(horizontal: false, vertical: true)
                Text("It reads a real barcode, but it is not connected to a product database. There is no ingredient lookup, no brand data and no grading behind it — what you see after a scan is a demonstration of the format, not a verdict on the product in your hand.")
                    .bodyText(15)
                    .foregroundStyle(Theme.cream.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Don't use it to decide whether a supplement is safe or worth buying. Read the label, and ask a pharmacist about anything you take alongside medication.")
                    .captionText(13)
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

    // MARK: Reporting

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Found a problem?")
                .sectionEyebrow()

            SettingsRow(
                title: "Report an issue with a remedy",
                detail: queuedReports == 0
                    ? "Wrong citation, missing safety warning, or a preparation that doesn't match its source"
                    : "\(queuedReports) report\(queuedReports == 1 ? "" : "s") saved on this device, not yet sent"
            ) {
                isReporting = true
            }
        }
    }

    // MARK: Reserved slots

    /// The safety-banner preview toggle used to live on the chat-header bell. The bell now
    /// opens Updates, so the preview moved to the screen that explains unfinished features —
    /// which is a better home for it than a control that looked like a live alert switch.
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unfinished by design")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 14) {
                Text("Grounded reserves a banner above the chat for urgent-care warnings. Nothing triggers it: red-flag detection has to be its own deterministic layer, not a judgement call from the model that writes the reply, and that layer isn't built.")
                    .bodyText(15)
                    .foregroundStyle(Theme.cream.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(Theme.hairline)

                Toggle(isOn: Binding(
                    get: { appModel.isSafetyBannerPreviewActive },
                    set: { appModel.isSafetyBannerPreviewActive = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Preview the safety banner")
                            .uiLabel(15)
                            .foregroundStyle(Theme.cream)
                        Text("Shows the reserved banner in Chat. It resets when you close the app.")
                            .captionText(12)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(Theme.cream)
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
}
