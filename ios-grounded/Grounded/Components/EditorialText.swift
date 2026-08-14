import SwiftUI

/// Opening paragraph with an oversized initial in the display face.
///
/// This is a *raised* initial, not a true drop cap: SwiftUI has no text-wrap-around, so a
/// letter that sinks into the paragraph would need the following two lines manually inset,
/// which breaks the moment the text reflows for Dynamic Type or a longer ailment string.
/// Concatenating the cap into the same `Text` keeps it one wrapping paragraph — the cap
/// sits on the first line's baseline and the rest of the text flows around it normally.
struct DropCapParagraph: View {
    let text: String
    var capSize: CGFloat = 34
    var bodySize: CGFloat = 15
    var color: Color = Theme.cream.opacity(0.85)

    var body: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A leading non-letter (a digit, a quote) would make a poor initial, so the cap is
        // only lifted out when the paragraph actually starts on a letter.
        let canCap = trimmed.first?.isLetter == true

        Group {
            if canCap {
                (
                    Text(String(trimmed.prefix(1)).uppercased())
                        .font(Typography.display(capSize, 800))
                        .tracking(1)
                        + Text(String(trimmed.dropFirst()))
                        .font(Typography.body(bodySize, 400))
                )
                .foregroundStyle(color)
            } else {
                Text(trimmed)
                    .bodyText(bodySize)
                    .foregroundStyle(color)
            }
        }
        .lineSpacing(
            Typography.lineSpacing(
                size: bodySize,
                multiple: 1.5,
                family: Typography.bodyFamily,
                weight: 400
            )
        )
        .fixedSize(horizontal: false, vertical: true)
        // The cap is a typographic treatment, not a separate word — without this VoiceOver
        // reads the initial as its own element.
        .accessibilityLabel(trimmed)
    }
}

/// A single citation set apart from the numbered list: hairline rules above and below,
/// reading size rather than caption size, and generous leading. Used for the primary source
/// on Remedy Detail, where the citation is the point rather than a footnote.
struct PullQuote: View {
    let text: String
    var eyebrow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            rule
            VStack(alignment: .leading, spacing: 8) {
                if let eyebrow {
                    Text(eyebrow)
                        .sectionEyebrow(12, color: Theme.creamMuted)
                }
                Text(text)
                    .font(Typography.body(15, 400))
                    .foregroundStyle(Theme.cream.opacity(0.92))
                    // Looser than body's 1.5 — the rules give it room, and a citation is
                    // read slowly and once, not skimmed.
                    .lineSpacing(
                        Typography.lineSpacing(
                            size: 15,
                            multiple: 1.75,
                            family: Typography.bodyFamily,
                            weight: 400
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            rule
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(Theme.cream.opacity(0.22))
            .frame(height: 1)
    }
}

/// Shelf-level "read this one closely" mark: a neutral outline triangle in cream, never red.
///
/// Red is reserved for the contraindication block inside Remedy Detail. A red mark on a
/// browsing list would read as a prohibition on a remedy that is, correctly prepared,
/// perfectly safe — the point here is to slow the reader down, not to warn them off.
struct CautionBadge: View {
    let signal: CautionSignal
    var tint: Color = Theme.cream
    var size: CGFloat = 13

    var body: some View {
        LineIcon(glyph: .caution, size: size, tint: tint.opacity(0.75))
            .accessibilityHidden(true)
    }
}
