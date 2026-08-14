import SwiftUI

/// Pill badge for a remedy's evidence tier. Supports all three tiers so the unused
/// "Reviewed by [team] herbalist" value can be switched on later without changes.
///
/// Deliberately icon-free: a seal, checkmark or badge glyph here would imply third-party
/// regulatory approval, which an educational-only app cannot claim. Text carries the tier.
///
/// The pill is the app-wide entry point to "How we source" — a tier claim should always be
/// one tap from its own definition. Set `explains: false` where the pill sits inside another
/// tappable row and the row's own destination has to win.
struct EvidenceTierBadge: View {
    let tier: EvidenceTier
    /// Set when the badge sits on a saturated category hue rather than a dark surface —
    /// the unfilled tier's wash and border are lifted so it stays legible on color.
    var onCategoryColor: Bool = false
    /// Tighter type and padding for the shelf card corner.
    var isCompact: Bool = false
    /// Set when the badge sits on the cream inverse surface. The whole pill is cream-based by
    /// default, so on cream it would otherwise disappear — this flips the pair rather than
    /// dimming it, keeping filled/unfilled reading as the same distinction.
    var onLightSurface: Bool = false
    /// When true the pill is a button opening the sourcing screen.
    var explains: Bool = true

    @State private var isShowingSourcing = false

    private var isFilled: Bool { tier == .clinical }

    var body: some View {
        Group {
            if explains {
                Button {
                    isShowingSourcing = true
                } label: {
                    pill
                }
                .buttonStyle(SoftPressStyle(scale: 0.96))
                .accessibilityHint("Explains how remedies are sourced and vetted")
            } else {
                pill
            }
        }
        .sheet(isPresented: $isShowingSourcing) {
            SourcingSheet(highlighted: tier)
        }
    }

    /// The ink the pill draws itself in: cream on dark surfaces, near-black on cream.
    private var ink: Color { onLightSurface ? Theme.onCream : Theme.cream }

    /// The colour a filled pill's label sits against, which is the opposite of `ink`.
    private var fillLabel: Color { onLightSurface ? Theme.cream : Theme.onCream }

    private var pill: some View {
        Text(tier.label)
            .uiLabel(isCompact ? 11 : 12)
            .foregroundStyle(isFilled ? fillLabel : ink.opacity(onCategoryColor ? 0.95 : 0.85))
            // Padding picks up the room the removed glyph used to occupy, so the pill keeps
            // its previous optical width rather than shrinking to a bare word.
            .padding(.horizontal, isCompact ? 11 : 13)
            .padding(.vertical, isCompact ? 4 : 5)
            .background {
                Capsule(style: .continuous)
                    .fill(isFilled ? ink : ink.opacity(onCategoryColor ? 0.18 : 0.10))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(ink.opacity(isFilled ? 0 : (onCategoryColor ? 0.38 : 0.28)), lineWidth: 1)
            }
            .fixedSize()
            .accessibilityLabel("Evidence: \(tier.label)")
    }
}

/// Secondary caption for a remedy's `evidenceNote` — real nuance, kept visually
/// subordinate to the tier badge itself.
struct EvidenceNoteCaption: View {
    let note: String
    var lineLimit: Int? = 3

    var body: some View {
        Text(note)
            .captionText(12, italic: true)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
