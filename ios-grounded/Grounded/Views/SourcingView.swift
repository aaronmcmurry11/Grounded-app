import SwiftUI

/// "How we source" — the trust screen behind every evidence-tier pill, and a row in Account.
///
/// All copy here is assembled from what the project already wrote: the tier definitions
/// authored in `remedies.json`, the onboarding disclaimer, and counts derived from the seed
/// data itself. The counts are computed, never typed, so the screen cannot drift out of sync
/// with the library.
struct SourcingView: View {
    /// Tier the user arrived from, given a quiet cream border so the answer to "what does
    /// *this* pill mean" is findable without scrolling hunting.
    var highlighted: EvidenceTier?

    @Environment(RemedyLibrary.self) private var library

    /// The library decodes a bundled file during init, so this is only true if decoding
    /// failed mid-flight. It exists so the screen has a defined loading contract for when
    /// sourcing content moves server-side — and skeletons, never a spinner, are that contract.
    private var isAwaitingLibrary: Bool {
        library.remedies.isEmpty && !library.loadFailed
    }

    private let populatedTiers: [EvidenceTier] = [.traditionalUse, .clinical]

    var body: some View {
        ZStack {
            AtmosphericBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    tiersSection
                    vettingSection
                    sourceBaseSection
                    footnote
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Trust & sourcing")
                .sectionEyebrow(13, color: Theme.cream.opacity(0.7))
            // Hero Display stays reserved for the wordmark and remedy names — a utility
            // screen title belongs to the Screen Headline role.
            Text("How we source")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)
            Text("Every remedy in Grounded carries a tier that says what kind of evidence sits behind it. Grounded shares educational information drawn from a curated, cited source base — the tiers describe that source base honestly, including where it's thin.")
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

    // MARK: Tiers

    private var tiersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our evidence tiers")
                .sectionEyebrow()

            if isAwaitingLibrary {
                ForEach(0..<2, id: \.self) { _ in tierSkeleton }
            } else {
                ForEach(populatedTiers, id: \.self) { tier in
                    tierCard(tier)
                }
                unusedTierCard
            }
        }
    }

    private func tierCard(_ tier: EvidenceTier) -> some View {
        let count = library.count(for: tier)
        let isHighlighted = highlighted == tier

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                // `explains: false` — this pill is already inside the explanation.
                EvidenceTierBadge(tier: tier, explains: false)
                Spacer(minLength: 8)
                Text(count == 1 ? "1 remedy" : "\(count) remedies")
                    .captionText(12)
            }

            Text(library.definition(for: tier))
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.86))
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
                .strokeBorder(
                    isHighlighted ? Theme.cream.opacity(0.42) : Theme.hairline,
                    lineWidth: isHighlighted ? 1.6 : 1
                )
        }
    }

    /// The third tier is in the data model but has no content behind it. Saying so plainly is
    /// the trustworthy option — quietly hiding it would make the tier system look complete.
    private var unusedTierCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reviewed by a herbalist")
                .uiLabel(15)
                .foregroundStyle(Theme.creamMuted)
            Text("Not currently in use. No practitioner reviews entries today, so no remedy in Grounded carries this tier. If that changes, it will appear here first.")
                .captionText(13)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.cream.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }

    private var tierSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBar(width: 120, height: 22)
            SkeletonBar(height: 11)
            SkeletonBar(width: 210, height: 11)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
    }

    // MARK: Vetting

    private var vettingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How an entry gets vetted")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 16) {
                step(1, "Every remedy is written from scratch against primary sources — regulatory herbal monographs such as NCCIH, the EMA's herbal committee and Health Canada's natural-health database, plus peer-reviewed human studies where they exist.")
                step(2, "The tier is assigned from what those sources actually support, not from how well the remedy is known. A widely-used remedy with no trials behind it stays at Traditional use.")
                step(3, "Study funding is checked. Where a positive trial was paid for, supplied or co-designed by a manufacturer of the product being tested, that is recorded and weighed against independent reviews.")
                step(4, "Tiers get downgraded when the funding picture doesn't hold up. When an entry has been moved, the reason is written into the note on its own detail screen.")
                step(5, "Contraindications and interactions are carried on the entry itself, flagged where they matter most.")
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

    private func step(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StepNumberRing(number: index)
            Text(text)
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Source base

    private var sourceBaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The library today")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 14) {
                if isAwaitingLibrary {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack {
                            SkeletonBar(width: 150, height: 11)
                            Spacer()
                            SkeletonBar(width: 28, height: 11)
                        }
                    }
                } else if library.loadFailed {
                    Text("The remedy library could not be opened, so these counts are unavailable.")
                        .captionText(13)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    stat("Remedies", "\(library.remedies.count)")
                    Divider().overlay(Theme.hairline)
                    stat("Citations behind them", "\(library.citationCount)")
                    Divider().overlay(Theme.hairline)
                    stat("Entries with a funding check recorded", "\(library.fundingCheckedCount)")
                    Divider().overlay(Theme.hairline)
                    stat("Entries carrying a safety flag", "\(library.safetyFlaggedCount)")
                    Divider().overlay(Theme.hairline)
                    stat("Entries with an evidence note", "\(library.annotatedCount)")
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
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 10)
            Text(value)
                .uiLabel(15)
                .foregroundStyle(Theme.cream)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Footnote

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What this isn't")
                .sectionEyebrow()
            Text("Grounded's entries are not clinically validated, and a tier is not a recommendation. Nothing here diagnoses, treats or replaces care from a qualified professional — always speak with a clinician about your symptoms and any medication or supplement you take.")
                .captionText(13)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(Theme.safetyRed)
                    .frame(width: 5, height: 5)
                    .padding(.top, 6)
                Text("In an emergency, call 911 or your local emergency number.")
                    .captionText(13, color: Theme.cream)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }
}

/// Sheet wrapper used when the sourcing screen is opened from an evidence-tier pill rather
/// than pushed from Account.
struct SourcingSheet: View {
    let highlighted: EvidenceTier?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SourcingView(highlighted: highlighted)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Theme.cream)
                    }
                }
        }
        .tint(Theme.cream)
        .presentationBackground(Theme.background)
    }
}
