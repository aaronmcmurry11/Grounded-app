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

/// Renders a dosage/frequency sentence with its dose amounts (a number or range plus a unit
/// — "1 tsp", "300–600 mg", "2 tablets") lifted to Semibold at a touch larger than the
/// surrounding sentence, with tabular (fixed-width) figures throughout so numbers align
/// instead of jittering line to line. Everything else in the sentence stays regular body text.
///
/// `dosageFrequency` is a single freeform sentence in the data (there's no separate
/// number/unit field to key off), so this finds dose-shaped substrings with a regex rather
/// than requiring the content to be restructured — matches a quantity (digit(s), a decimal,
/// or a unicode fraction like ½, optionally a range with the two joined by a dash) directly
/// followed by a known dose unit.
struct DosageText: View {
    let text: String
    var baseSize: CGFloat = 15
    var color: Color = Theme.cream.opacity(0.92)

    private static let doseRegex = try? NSRegularExpression(
        pattern: #"(?:½|⅓|⅔|¼|¾|\d+(?:\.\d+)?)(?:\s*[–-]\s*(?:½|⅓|⅔|¼|¾|\d+(?:\.\d+)?))?\s*(?:tsp|tbsp|mg|mcg|mL|ml|oz|g|tablets?|capsules?|cloves?|cups?|drops?)\b"#
    )

    var body: some View {
        segments
            .reduce(Text("")) { $0 + $1 }
            .lineSpacing(
                Typography.lineSpacing(
                    size: baseSize,
                    multiple: Typography.lerp(1.5, 1.6, size: baseSize, in: 15...16),
                    family: Typography.bodyFamily,
                    weight: 400
                )
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    private var segments: [Text] {
        guard let regex = Self.doseRegex else { return [plainRun(text)] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [plainRun(text)] }

        var result: [Text] = []
        var cursor = 0
        for match in matches {
            let range = match.range
            if range.location > cursor {
                result.append(plainRun(nsText.substring(with: NSRange(location: cursor, length: range.location - cursor))))
            }
            result.append(doseRun(nsText.substring(with: range)))
            cursor = range.location + range.length
        }
        if cursor < nsText.length {
            result.append(plainRun(nsText.substring(from: cursor)))
        }
        return result
    }

    private func plainRun(_ segment: String) -> Text {
        Text(segment)
            .font(Typography.body(baseSize, 400))
            .foregroundColor(color)
    }

    private func doseRun(_ segment: String) -> Text {
        Text(segment)
            .font(Typography.body(baseSize + 1, 600))
            .foregroundColor(Theme.cream)
            .monospacedDigit()
    }
}

/// A single numbered source citation. The study title (the text between the first pair of
/// quotes, when present) renders in italic against the regular-weight author/year/journal
/// text around it, and — when the source string ends in a funding or conflict-of-interest
/// parenthetical — that note is lifted out onto its own smaller, dimmed line under a
/// "FUNDING" label rather than running together with the citation itself. The seed data has
/// no separate funding field, so this is detected from the trailing parenthetical rather than
/// requiring the content to be restructured; a keyword check (`fund`, `sponsor`,
/// `independent`, `conflict`, `competing interest`) keeps it from misreading an unrelated
/// trailing parenthetical, like a bare year or a participant count, as a funding note.
struct SourceCitation: View {
    let index: Int
    let source: String

    private static let fundingKeywords = ["fund", "sponsor", "independent", "conflict", "competing interest"]

    private var parts: (citation: String, funding: String?) {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(")"), let openParen = trimmed.lastIndex(of: "(") else {
            return (trimmed, nil)
        }
        let candidate = trimmed[openParen...]
        guard Self.fundingKeywords.contains(where: { candidate.lowercased().contains($0) }) else {
            return (trimmed, nil)
        }
        let citation = trimmed[trimmed.startIndex..<openParen].trimmingCharacters(in: .whitespaces)
        let funding = candidate.dropFirst().dropLast() // strip the surrounding parens
        return (citation, String(funding))
    }

    /// Splits on the citation's first quoted span so the study title alone italicizes,
    /// leaving author/year/journal in the surrounding regular weight. Falls back to a single
    /// plain run when a source has no quoted title to find.
    private func citationText(_ citation: String) -> Text {
        guard let openQuote = citation.firstIndex(of: "\""),
              let closeQuote = citation[citation.index(after: openQuote)...].firstIndex(of: "\"") else {
            return Text(citation).font(Typography.body(12, 400)).foregroundColor(Theme.creamSecondary)
        }
        let before = String(citation[citation.startIndex..<openQuote])
        let title = String(citation[citation.index(after: openQuote)..<closeQuote])
        let after = String(citation[citation.index(after: closeQuote)...])

        return Text(before)
            .font(Typography.body(12, 400))
            .foregroundColor(Theme.creamSecondary)
            + Text("\u{201C}\(title)\u{201D}")
            .font(Typography.body(12, 400))
            .italic()
            .foregroundColor(Theme.creamSecondary)
            + Text(after)
            .font(Typography.body(12, 400))
            .foregroundColor(Theme.creamSecondary)
    }

    var body: some View {
        let (citation, funding) = parts

        // The number sits in its own fixed-width column beside a flexible text column, so
        // wrapped lines fall in under the first line rather than back under the number — a
        // hanging indent without needing SwiftUI's nonexistent paragraph-indent APIs.
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .uiLabel(11, weight: 700)
                .foregroundStyle(Theme.creamMuted)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Theme.cream.opacity(0.08)))

            VStack(alignment: .leading, spacing: 6) {
                citationText(citation)
                    .lineSpacing(
                        Typography.lineSpacing(size: 12, multiple: 1.45, family: Typography.bodyFamily, weight: 400)
                    )
                    .fixedSize(horizontal: false, vertical: true)

                if let funding {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Funding")
                            .sectionEyebrow(10, color: Theme.creamFaint)
                        Text(funding)
                            .captionText(11, color: Theme.creamFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
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
