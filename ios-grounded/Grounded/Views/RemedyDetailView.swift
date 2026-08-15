import SwiftUI
import UIKit

struct RemedyDetailView: View {
    let remedy: Remedy
    /// Provided when the detail view is pushed from Apothecary — returns to chat
    /// with this remedy as context. Nil when already presented from chat.
    let onFollowUp: ((Remedy) -> Void)?

    @Environment(RemedyLibrary.self) private var library
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    /// Collapsed by default: the funding notes are long, specific, and matter most to the
    /// reader who goes looking for them. Front-loading them would bury the remedy itself.
    @State private var isTransparencyExpanded = false
    @State private var isReporting = false

    private var categoryColor: Color {
        Theme.categoryColor(library.colorHex(forCategory: remedy.category))
    }

    var body: some View {
        ZStack {
            AtmosphericBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    evidenceSection
                    section(title: "Ingredients", icon: "leaf") {
                        ForEach(remedy.ingredients, id: \.self) { item in
                            bullet(item)
                        }
                    }
                    section(title: "Preparation", icon: "mortar.and.pestle") {
                        ForEach(Array(remedy.directions.enumerated()), id: \.offset) { index, step in
                            numbered(index: index + 1, text: step)
                        }
                    }
                    section(title: "Dosage & frequency", icon: "clock", glyph: .clock) {
                        DosageText(text: remedy.dosageFrequency)
                    }
                    safetySection
                    sourcesSection
                    actions
                }
                .padding(.horizontal, 18)
                // Works for both presentations: pushed inside a tab it inherits the tab bar
                // inset, and as a sheet from chat there is no bar to clear.
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    appModel.toggleBookmark(remedy)
                } label: {
                    LineIcon(
                        glyph: appModel.isBookmarked(remedy) ? .bookmarkSaved : .bookmark,
                        size: 20
                    )
                }
                .accessibilityLabel(appModel.isBookmarked(remedy) ? "Remove from saved" : "Save remedy")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $isReporting) {
            ReportIssueView(remedy: remedy)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(remedy.category)
                    .sectionEyebrow(13, color: Theme.cream.opacity(0.7))
                Text(library.formattedCatalogNumber(for: remedy))
                    .catalogNumber(12, color: Theme.cream.opacity(0.5))
                if let signal = remedy.cautionSignal {
                    CautionBadge(signal: signal, size: 13)
                        .accessibilityHidden(false)
                        .accessibilityLabel("Read closely: \(signal.reason)")
                }
            }
            Text(remedy.name)
                .heroDisplay(40)
                .foregroundStyle(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)

            // The label is lifted out into an eyebrow so the description below it can open
            // on a real word — a drop cap on "Traditionally" would cap the boilerplate
            // rather than the remedy's own sentence.
            VStack(alignment: .leading, spacing: 4) {
                Text("Traditionally used for")
                    .sectionEyebrow(12, color: Theme.cream.opacity(0.6))
                DropCapParagraph(
                    text: remedy.ailment,
                    capSize: 34,
                    bodySize: 15,
                    color: Theme.cream.opacity(0.92)
                )
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(categoryColor)
        }
        .overlay(alignment: .topTrailing) {
            BotanicalSprig(lineWidth: 1)
                .frame(width: 60, height: 84)
                .opacity(0.45)
                .padding(16)
        }
        .ambientElevation(.raised)
    }

    // MARK: Evidence

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EvidenceTierBadge(tier: remedy.evidenceTier)
            Text(remedy.evidenceTier.explanation)
                .captionText(13)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Theme.hairline)
            transparencyDisclosure
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

    // MARK: Sourcing transparency

    private var isFundingChecked: Bool { remedy.fundingConflictChecked == true }

    /// Shown collapsed on the row itself, so the state is readable without expanding.
    private var fundingStatus: String {
        isFundingChecked ? "Funding checked" : "Not recorded"
    }

    /// Tap-to-expand disclosure carrying the funding-conflict notes already written into the
    /// seed data. These used to render inline and unprompted, which put three dense
    /// paragraphs about industry funding above the actual preparation steps on entries like
    /// elderberry. Labelled and collapsed, the nuance is one tap away instead of in the way.
    private var transparencyDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isTransparencyExpanded.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    UIChromeIcon(systemName: "info.circle", size: 11)
                    Text("Sourcing transparency")
                        .sectionEyebrow(12)
                    Spacer(minLength: 8)
                    Text(fundingStatus)
                        .captionText(11, color: Theme.creamFaint)
                    UIChromeIcon(systemName: "chevron.down", size: 10, color: Theme.creamFaint)
                        .rotationEffect(.degrees(isTransparencyExpanded ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(SoftPressStyle(scale: 0.995))
            .accessibilityLabel("Sourcing transparency, \(fundingStatus)")
            .accessibilityHint(isTransparencyExpanded ? "Collapses the sourcing notes" : "Expands the sourcing notes")

            if isTransparencyExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if let note = remedy.evidenceNote {
                        EvidenceNoteCaption(note: note, lineLimit: nil)
                    }
                    // Stated either way. Silence on an unchecked entry would let the reader
                    // assume every entry got the same scrutiny.
                    Text(
                        isFundingChecked
                            ? "Funding behind this entry's cited studies was checked and recorded."
                            : "No funding-conflict check is recorded for this entry's sources."
                    )
                    .captionText(12)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
    }

    // MARK: Safety

    private var hasSafetyFlag: Bool { remedy.safetyFlag != nil }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                // Warning triangle: stroke weight harmonized to the chrome token, shape and
                // safety-red color untouched. It never softens and never gets decoration.
                UIChromeIcon(
                    systemName: hasSafetyFlag ? "exclamationmark.triangle.fill" : "shield",
                    size: 12,
                    color: hasSafetyFlag ? Theme.safetyRed : Theme.creamMuted
                )
                Text("Safety & contraindications")
                    .sectionEyebrow()
            }

            if let flag = remedy.safetyFlag {
                Text(flag.replacingOccurrences(of: "-", with: " ").capitalized)
                    .sectionEyebrow(12, color: Theme.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule(style: .continuous).fill(Theme.safetyRed)
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(remedy.contraindications, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(hasSafetyFlag ? Theme.safetyRed : Theme.creamFaint)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(item)
                            .bodyText(15)
                            .foregroundStyle(Theme.cream.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Compliance copy stays upright, not italic, so it reads as plainly as possible.
            Text("Not medical advice. Check with a clinician before starting anything, especially alongside medication.")
                .captionText(12)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(hasSafetyFlag ? Theme.safetyRed.opacity(0.10) : Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(hasSafetyFlag ? Theme.safetyRed.opacity(0.65) : Theme.hairline, lineWidth: hasSafetyFlag ? 1.5 : 1)
        }
    }

    // MARK: Sources

    private var sourcesSection: some View {
        section(title: "Sources", icon: "text.book.closed") {
            // The primary citation is set apart rather than pulled out: it stays as entry 1
            // in the list below, so the numbering still matches anything that references it.
            if let primary = remedy.sources.first {
                PullQuote(text: primary, eyebrow: "Primary source")
                    .padding(.bottom, 4)
            }

            ForEach(Array(remedy.sources.enumerated()), id: \.offset) { index, source in
                SourceCitation(index: index + 1, source: source)
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                title: appModel.isBookmarked(remedy) ? "Saved" : "Save remedy",
                glyph: appModel.isBookmarked(remedy) ? .bookmarkSaved : .bookmark
            ) {
                appModel.toggleBookmark(remedy)
            }

            QuietButton(title: "Ask a follow-up in chat", glyph: .chat) {
                if let onFollowUp {
                    onFollowUp(remedy)
                } else {
                    dismiss()
                }
            }

            // Sits below the two primary actions and carries no icon: reporting a problem is
            // a real affordance on every entry, but it shouldn't compete with reading one.
            Button {
                isReporting = true
            } label: {
                Text("Report an issue with this remedy")
                    .uiLabel(13)
                    .foregroundStyle(Theme.creamMuted)
                    .underline(true, pattern: .solid)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(.rect)
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(.top, 4)
    }

    // MARK: Building blocks

    /// `glyph` takes precedence when the section's mark exists in the Tier C set; the
    /// remaining section marks (leaf, mortar, book) stay on weight-harmonized symbols until
    /// they're drawn properly.
    private func section<Content: View>(
        title: String,
        icon: String,
        glyph: LineGlyph? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                if let glyph {
                    LineIcon(glyph: glyph, size: 14, tint: Theme.creamMuted)
                } else {
                    UIChromeIcon(systemName: icon, size: 12)
                }
                Text(title)
                    .sectionEyebrow()
            }
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
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

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Theme.creamFaint)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func numbered(index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StepNumberRing(number: index)
            Text(text)
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
