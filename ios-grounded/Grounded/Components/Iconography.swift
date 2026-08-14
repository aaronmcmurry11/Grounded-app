import SwiftUI

// MARK: - The four iconography tiers
//
// Grounded's icons and illustrations sit in one of four tiers, chosen by *where* the mark
// appears rather than by what it depicts. The tier decides density, stroke, and opacity.
//
// Tier A — "full engraving". Remedy hero art, onboarding, empty states. Fine hairline
//   strokes with hatching and stippling, deliberately dialled back from period-engraving
//   density because this is cream-on-dark and true engraving density turns to mud.
//   `BotanicalSprig` is the current Tier A mark.
//
// Tier B — "reduced engraving". Category icons, roughly 24–32px. One silhouette contour
//   plus 2–4 interior lines, maximum. No hatching — it closes up at this size.
//
// Tier C — "brand-flavored functional icon". Nav bar, prep-type icons. Uniform
//   `Theme.iconStroke` stroke, rounded terminals, no fill, no interior hatching. Drawn
//   rather than borrowed from SF Symbols so the weight matches the botanical linework.
//   `LineIcon` and `PrepTypeIcon` are this tier.
//
// Tier D — "pure UI chrome". Send, delete, checkboxes, chevrons. No woodcut treatment at
//   all — conventional system symbols, harmonized only in stroke weight and corner feel
//   via `UIChromeIcon` so they sit alongside Tier C without matching it.
//
// Color rules, all tiers:
// - Linework is always the cream token. Never recolored into a category hue, never a new
//   color. The one exception is the safety-red warning triangle, which is never anything
//   but red and never gets botanical decoration.
// - On category-colored cards, render at full opacity directly on the fill.
// - On neutral dark backgrounds, large illustrations sit at 60–80% opacity so they recede
//   behind text. Small functional icons stay full opacity.

/// Tier C glyph set. Drawn in a unit square and stroked at a fixed point width, so the
/// line weight stays constant across sizes instead of scaling with the glyph.
nonisolated enum LineGlyph {
    case chat
    case apothecary
    case scan
    case account
    case bookmark
    case bookmarkSaved
    case clock
    case search
    /// Chat-header inbox mark. Drawn rather than left on `bell.badge` so the one icon in the
    /// header carries the same stroke weight and rounded terminals as the tab bar beneath it.
    case bell
    /// Neutral outline triangle for the shelf-level caution mark. Deliberately *not* the
    /// safety-red filled triangle used inside Remedy Detail — this one says "read closely",
    /// not "danger", and is never rendered in red.
    case caution
}

/// Tier C icon: uniform cream stroke, rounded terminals, no fill.
struct LineIcon: View {
    let glyph: LineGlyph
    var size: CGFloat = 20
    var tint: Color = Theme.cream
    /// Optically heavier variant for selected states. Stays inside the 1.5–2pt band.
    var isEmphasized: Bool = false

    private var lineWidth: CGFloat {
        isEmphasized ? Theme.iconStrokeEmphasized : Theme.iconStroke
    }

    var body: some View {
        Canvas { context, canvas in
            let w = canvas.width
            let h = canvas.height
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let full = GraphicsContext.Shading.color(tint)
            let quiet = GraphicsContext.Shading.color(tint.opacity(0.55))

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: w * x, y: h * y)
            }

            switch glyph {
            case .chat:
                var bubble = Path()
                bubble.addRoundedRect(
                    in: CGRect(x: w * 0.10, y: h * 0.16, width: w * 0.80, height: h * 0.54),
                    cornerSize: CGSize(width: w * 0.18, height: w * 0.18),
                    style: .continuous
                )
                context.stroke(bubble, with: full, style: style)

                var tail = Path()
                tail.move(to: point(0.30, 0.70))
                tail.addLine(to: point(0.30, 0.90))
                tail.addLine(to: point(0.50, 0.70))
                context.stroke(tail, with: full, style: style)

                // Two interior lines read as speech without becoming hatching.
                for row in [0.36, 0.52] {
                    var line = Path()
                    line.move(to: point(0.28, row))
                    line.addLine(to: point(0.72, row))
                    context.stroke(line, with: quiet, style: style)
                }

            case .apothecary:
                // Apothecary jar: lid, shoulder, body.
                var lid = Path()
                lid.move(to: point(0.32, 0.12))
                lid.addLine(to: point(0.68, 0.12))
                context.stroke(lid, with: full, style: style)

                var neck = Path()
                neck.move(to: point(0.38, 0.12))
                neck.addLine(to: point(0.38, 0.26))
                neck.move(to: point(0.62, 0.12))
                neck.addLine(to: point(0.62, 0.26))
                context.stroke(neck, with: full, style: style)

                var body = Path()
                body.addRoundedRect(
                    in: CGRect(x: w * 0.20, y: h * 0.26, width: w * 0.60, height: h * 0.62),
                    cornerSize: CGSize(width: w * 0.16, height: w * 0.16),
                    style: .continuous
                )
                context.stroke(body, with: full, style: style)

                var level = Path()
                level.move(to: point(0.20, 0.56))
                level.addLine(to: point(0.80, 0.56))
                context.stroke(level, with: quiet, style: style)

            case .scan:
                // Four viewfinder brackets plus three barcode strokes.
                let inset: CGFloat = 0.14
                let arm: CGFloat = 0.18
                for (cx, cy, sx, sy) in [
                    (inset, inset, 1.0, 1.0),
                    (1 - inset, inset, -1.0, 1.0),
                    (inset, 1 - inset, 1.0, -1.0),
                    (1 - inset, 1 - inset, -1.0, -1.0),
                ] {
                    var bracket = Path()
                    bracket.move(to: point(cx + arm * sx, cy))
                    bracket.addLine(to: point(cx, cy))
                    bracket.addLine(to: point(cx, cy + arm * sy))
                    context.stroke(bracket, with: full, style: style)
                }

                for x in [0.38, 0.50, 0.62] {
                    var bar = Path()
                    bar.move(to: point(x, 0.32))
                    bar.addLine(to: point(x, 0.68))
                    context.stroke(bar, with: x == 0.50 ? full : quiet, style: style)
                }

            case .account:
                var head = Path()
                head.addEllipse(in: CGRect(x: w * 0.32, y: h * 0.14, width: w * 0.36, height: h * 0.36))
                context.stroke(head, with: full, style: style)

                var shoulders = Path()
                shoulders.move(to: point(0.16, 0.90))
                shoulders.addQuadCurve(to: point(0.84, 0.90), control: point(0.50, 0.52))
                context.stroke(shoulders, with: full, style: style)

            case .bookmark, .bookmarkSaved:
                var pennant = Path()
                pennant.move(to: point(0.26, 0.12))
                pennant.addLine(to: point(0.74, 0.12))
                pennant.addLine(to: point(0.74, 0.88))
                pennant.addLine(to: point(0.50, 0.66))
                pennant.addLine(to: point(0.26, 0.88))
                pennant.closeSubpath()
                context.stroke(pennant, with: full, style: style)

                if glyph == .bookmarkSaved {
                    // Saved state is a nested second contour, not a fill — the double-line
                    // language shared with the prep-step number rings.
                    var inner = Path()
                    inner.move(to: point(0.37, 0.26))
                    inner.addLine(to: point(0.63, 0.26))
                    inner.addLine(to: point(0.63, 0.62))
                    inner.addLine(to: point(0.50, 0.50))
                    inner.addLine(to: point(0.37, 0.62))
                    inner.closeSubpath()
                    context.stroke(inner, with: full, style: style)
                }

            case .clock:
                var dial = Path()
                dial.addEllipse(in: CGRect(x: w * 0.12, y: h * 0.12, width: w * 0.76, height: h * 0.76))
                context.stroke(dial, with: full, style: style)

                var hands = Path()
                hands.move(to: point(0.50, 0.30))
                hands.addLine(to: point(0.50, 0.52))
                hands.addLine(to: point(0.68, 0.60))
                context.stroke(hands, with: full, style: style)

            case .search:
                var lens = Path()
                lens.addEllipse(in: CGRect(x: w * 0.14, y: h * 0.14, width: w * 0.56, height: h * 0.56))
                context.stroke(lens, with: full, style: style)

                var handle = Path()
                handle.move(to: point(0.64, 0.64))
                handle.addLine(to: point(0.88, 0.88))
                context.stroke(handle, with: full, style: style)

            case .bell:
                // Dome, shoulders and a closing base line, then a separate clapper arc. No
                // badge dot in the glyph itself — unread state is composed on top, so the
                // mark doesn't have to be redrawn to change meaning.
                var dome = Path()
                dome.move(to: point(0.17, 0.70))
                dome.addQuadCurve(to: point(0.32, 0.30), control: point(0.29, 0.62))
                dome.addQuadCurve(to: point(0.68, 0.30), control: point(0.50, 0.14))
                dome.addQuadCurve(to: point(0.83, 0.70), control: point(0.71, 0.62))
                dome.closeSubpath()
                context.stroke(dome, with: full, style: style)

                var clapper = Path()
                clapper.move(to: point(0.41, 0.78))
                clapper.addQuadCurve(to: point(0.59, 0.78), control: point(0.50, 0.90))
                context.stroke(clapper, with: quiet, style: style)

            case .caution:
                // Rounded joins keep it from reading as a hazard placard.
                var triangle = Path()
                triangle.move(to: point(0.50, 0.12))
                triangle.addLine(to: point(0.93, 0.85))
                triangle.addLine(to: point(0.07, 0.85))
                triangle.closeSubpath()
                context.stroke(triangle, with: full, style: style)

                var stem = Path()
                stem.move(to: point(0.50, 0.40))
                stem.addLine(to: point(0.50, 0.60))
                context.stroke(stem, with: full, style: style)

                var dot = Path()
                dot.move(to: point(0.50, 0.71))
                dot.addLine(to: point(0.50, 0.72))
                context.stroke(dot, with: full, style: style)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

/// Tier D chrome: a conventional system symbol, harmonized only in weight so it reads at
/// the same optical density as the Tier C set. Shape is deliberately left alone.
struct UIChromeIcon: View {
    let systemName: String
    var size: CGFloat = 13
    var weight: Font.Weight = Theme.chromeIconWeight
    var color: Color = Theme.creamMuted

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }
}

/// Prep-step numeral inside a thin double-ring, replacing the old solid cream disc. Cream
/// on dark at the Tier C stroke weight, so a step marker no longer out-weighs the step text.
struct StepNumberRing: View {
    let number: Int
    var diameter: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.cream.opacity(0.85), lineWidth: Theme.iconStroke)
            Circle()
                .strokeBorder(Theme.cream.opacity(0.30), lineWidth: Theme.iconStroke * 0.7)
                .padding(3)
            Text("\(number)")
                .uiLabel(12)
                .foregroundStyle(Theme.cream)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel("Step \(number)")
    }
}
