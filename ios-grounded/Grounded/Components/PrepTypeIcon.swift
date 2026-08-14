import SwiftUI

/// The preparation shapes a remedy can take, derived from the seed data's freeform
/// `prepType` string. Kept deliberately small: the shelf card only needs a glanceable
/// hint at *how* a remedy is made, and the full prep text lives on Remedy Detail.
nonisolated enum PrepKind {
    /// Brewed in water and drunk — infusions, decoctions, gargles.
    case tea
    /// Inhaled as vapour rather than swallowed.
    case steam
    /// Dosed in drops from a dropper bottle.
    case tincture
    /// Applied to skin — poultices, ointments, gels, dressings, soaks.
    case poultice
    /// Spooned or poured from a jar — syrups, honey, juices.
    case syrup
    /// Swallowed in a measured dose — capsules, tablets, supplements.
    case supplement

    /// Spoken form for the row's accessibility label, since the glyph itself is decorative.
    var label: String {
        switch self {
        case .tea: "Tea or infusion"
        case .steam: "Steam inhalation"
        case .tincture: "Tincture"
        case .poultice: "Topical preparation"
        case .syrup: "Syrup or spooned"
        case .supplement: "Capsule or tablet"
        }
    }

    /// Keyword table. Table order is the tie-break when two kinds match at the same
    /// position — it never decides a match on its own.
    private static let keywordTable: [(kind: PrepKind, needles: [String])] = [
        (.steam, ["steam", "inhalation", "aromatherapy", "essential oil", "vapour", "vapor"]),
        (.tincture, ["tincture", "dropper", "drops", "elixir", "fluid extract"]),
        // "taken straight" and "stirred into" describe something thick enough to spoon —
        // that's honey, not a brewed cup, even when the prose also mentions tea.
        (.syrup, ["syrup", "juice", "honey", "taken straight", "stirred into", "spoonful", "molasses"]),
        (.poultice, [
            "poultice", "topical", "ointment", "cream", "gel", "dressing", "bath",
            "soak", "salve", "balm", "compress", "liniment",
        ]),
        // Deliberately no "powder": powders are usually stirred into a drink ("Powder mixed
        // into a gruel/tea"), so the vessel is the truer image. A powder that really is a
        // dose still matches on "supplement" or "capsule".
        (.supplement, ["capsule", "tablet", "supplement", "softgel", "lozenge", "chewable", "whole food", "pill"]),
        (.tea, ["tea", "infusion", "decoction", "hot-water", "hot water", "gargle", "steep"]),
    ]

    /// `prepType` is prose, not an enum, so this classifies by keyword — but by *position*,
    /// not by a fixed priority list. Most entries name two routes ("Capsule, or root/rhizome
    /// tea", "Bath soak, or topical cream", "Aromatherapy (essential oil), or flower tea")
    /// and the seed data always names the primary route first, so the earliest match wins.
    /// A fixed priority order got these backwards — every "X, or … tea" landed on a teacup.
    static func classify(_ prepType: String) -> PrepKind {
        let value = prepType.lowercased()
        var best: (kind: PrepKind, offset: Int)?

        for entry in keywordTable {
            var earliest: Int?
            for needle in entry.needles {
                guard let range = value.range(of: needle) else { continue }
                let offset = value.distance(from: value.startIndex, to: range.lowerBound)
                earliest = min(earliest ?? offset, offset)
            }
            guard let earliest else { continue }
            if let current = best, earliest >= current.offset { continue }
            best = (entry.kind, earliest)
        }

        // Unrecognised prose is far more likely to be a swallowed dose than a brew or a
        // salve, so the catch-all is the neutral one rather than a specific vessel.
        return best?.kind ?? .supplement
    }
}

/// Fine-line prep glyph in the same stroked, woodcut-adjacent register as `BotanicalSprig`
/// — drawn rather than an SF Symbol so the weight matches the botanical artwork and the
/// icon set can't silently fall back to a missing symbol.
struct PrepTypeIcon: View {
    let kind: PrepKind
    var size: CGFloat = 18
    var tint: Color = Theme.cream

    init(prepType: String, size: CGFloat = 18, tint: Color = Theme.cream) {
        self.kind = PrepKind.classify(prepType)
        self.size = size
        self.tint = tint
    }

    init(kind: PrepKind, size: CGFloat = 18, tint: Color = Theme.cream) {
        self.kind = kind
        self.size = size
        self.tint = tint
    }

    var body: some View {
        Canvas { context, canvas in
            let width = canvas.width
            let height = canvas.height
            let line = max(1, size / 14)
            let stroke = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
            let color = GraphicsContext.Shading.color(tint)

            switch kind {
            case .tea:
                // Cup: tapered body, saucer, handle. No steam curls — those belong to
                // `.steam`, and sharing them made the two glyphs read alike at 18pt.
                let top = height * 0.30
                let bottom = height * 0.76
                var cup = Path()
                cup.move(to: CGPoint(x: width * 0.20, y: top))
                cup.addLine(to: CGPoint(x: width * 0.30, y: bottom))
                cup.addQuadCurve(
                    to: CGPoint(x: width * 0.62, y: bottom),
                    control: CGPoint(x: width * 0.46, y: bottom + height * 0.06)
                )
                cup.addLine(to: CGPoint(x: width * 0.72, y: top))
                cup.closeSubpath()
                context.stroke(cup, with: color, style: stroke)

                var handle = Path()
                handle.move(to: CGPoint(x: width * 0.74, y: top + height * 0.08))
                handle.addQuadCurve(
                    to: CGPoint(x: width * 0.68, y: top + height * 0.28),
                    control: CGPoint(x: width * 0.96, y: top + height * 0.18)
                )
                context.stroke(handle, with: color, style: stroke)

                // Surface line: reads as liquid in the cup, and separates tea from an
                // empty vessel without adding clutter.
                var brew = Path()
                brew.move(to: CGPoint(x: width * 0.24, y: top + height * 0.11))
                brew.addLine(to: CGPoint(x: width * 0.68, y: top + height * 0.11))
                context.stroke(brew, with: .color(tint.opacity(0.45)), style: stroke)

                var saucer = Path()
                saucer.move(to: CGPoint(x: width * 0.14, y: height * 0.90))
                saucer.addLine(to: CGPoint(x: width * 0.78, y: height * 0.90))
                context.stroke(saucer, with: .color(tint.opacity(0.75)), style: stroke)

            case .steam:
                // Swirls over a shallow basin — the vapour is the subject, so it takes the
                // top two-thirds and the vessel is only a base line.
                var basin = Path()
                basin.move(to: CGPoint(x: width * 0.18, y: height * 0.74))
                basin.addQuadCurve(
                    to: CGPoint(x: width * 0.82, y: height * 0.74),
                    control: CGPoint(x: width * 0.50, y: height * 0.99)
                )
                context.stroke(basin, with: color, style: stroke)

                var rim = Path()
                rim.move(to: CGPoint(x: width * 0.12, y: height * 0.72))
                rim.addLine(to: CGPoint(x: width * 0.88, y: height * 0.72))
                context.stroke(rim, with: color, style: stroke)

                // Centre swirl rises highest; the outer pair are shorter and mirrored, so
                // the plume reads as one movement rather than three parallel squiggles.
                let columns: [(x: Double, top: Double, sway: Double)] = [
                    (0.30, 0.30, -0.13),
                    (0.50, 0.10, 0.15),
                    (0.70, 0.30, -0.13),
                ]
                for column in columns {
                    let x = width * column.x
                    let base = height * 0.62
                    let apex = height * column.top
                    let mid = (base + apex) / 2
                    var swirl = Path()
                    swirl.move(to: CGPoint(x: x, y: base))
                    swirl.addQuadCurve(
                        to: CGPoint(x: x, y: mid),
                        control: CGPoint(x: x + width * column.sway, y: (base + mid) / 2)
                    )
                    swirl.addQuadCurve(
                        to: CGPoint(x: x, y: apex),
                        control: CGPoint(x: x - width * column.sway, y: (mid + apex) / 2)
                    )
                    context.stroke(swirl, with: .color(tint.opacity(0.9)), style: stroke)
                }

            case .tincture:
                // Dropper bottle: rubber-topped cap, shoulders, squat body, one dosed drop.
                var cap = Path()
                cap.addRoundedRect(
                    in: CGRect(x: width * 0.40, y: height * 0.04, width: width * 0.20, height: height * 0.14),
                    cornerSize: CGSize(width: width * 0.05, height: width * 0.05)
                )
                context.stroke(cap, with: color, style: stroke)

                var neck = Path()
                neck.move(to: CGPoint(x: width * 0.36, y: height * 0.20))
                neck.addLine(to: CGPoint(x: width * 0.64, y: height * 0.20))
                context.stroke(neck, with: color, style: stroke)

                var bottle = Path()
                bottle.move(to: CGPoint(x: width * 0.38, y: height * 0.22))
                bottle.addLine(to: CGPoint(x: width * 0.38, y: height * 0.30))
                bottle.addLine(to: CGPoint(x: width * 0.26, y: height * 0.44))
                bottle.addLine(to: CGPoint(x: width * 0.26, y: height * 0.86))
                bottle.addQuadCurve(
                    to: CGPoint(x: width * 0.34, y: height * 0.94),
                    control: CGPoint(x: width * 0.26, y: height * 0.94)
                )
                bottle.addLine(to: CGPoint(x: width * 0.66, y: height * 0.94))
                bottle.addQuadCurve(
                    to: CGPoint(x: width * 0.74, y: height * 0.86),
                    control: CGPoint(x: width * 0.74, y: height * 0.94)
                )
                bottle.addLine(to: CGPoint(x: width * 0.74, y: height * 0.44))
                bottle.addLine(to: CGPoint(x: width * 0.62, y: height * 0.30))
                bottle.addLine(to: CGPoint(x: width * 0.62, y: height * 0.22))
                context.stroke(bottle, with: color, style: stroke)

                // Tincture level, sitting low the way a dosed bottle does.
                var level = Path()
                level.move(to: CGPoint(x: width * 0.26, y: height * 0.62))
                level.addLine(to: CGPoint(x: width * 0.74, y: height * 0.62))
                context.stroke(level, with: .color(tint.opacity(0.5)), style: stroke)

            case .poultice:
                // Shallow bowl with a folded cloth draped over the rim.
                var bowl = Path()
                bowl.move(to: CGPoint(x: width * 0.10, y: height * 0.54))
                bowl.addQuadCurve(
                    to: CGPoint(x: width * 0.90, y: height * 0.54),
                    control: CGPoint(x: width * 0.50, y: height * 0.99)
                )
                context.stroke(bowl, with: color, style: stroke)

                var rim = Path()
                rim.move(to: CGPoint(x: width * 0.06, y: height * 0.52))
                rim.addLine(to: CGPoint(x: width * 0.94, y: height * 0.52))
                context.stroke(rim, with: color, style: stroke)

                // Two parallel edges give the cloth thickness — a single arc with a centre
                // vein read as a leaf, which collided with the botanical artwork.
                var cloth = Path()
                cloth.move(to: CGPoint(x: width * 0.24, y: height * 0.48))
                cloth.addQuadCurve(
                    to: CGPoint(x: width * 0.72, y: height * 0.48),
                    control: CGPoint(x: width * 0.48, y: height * 0.14)
                )
                context.stroke(cloth, with: .color(tint.opacity(0.85)), style: stroke)

                var fold = Path()
                fold.move(to: CGPoint(x: width * 0.33, y: height * 0.48))
                fold.addQuadCurve(
                    to: CGPoint(x: width * 0.63, y: height * 0.48),
                    control: CGPoint(x: width * 0.48, y: height * 0.29)
                )
                context.stroke(fold, with: .color(tint.opacity(0.5)), style: stroke)

                // Corner hanging over the near edge of the bowl.
                var drape = Path()
                drape.move(to: CGPoint(x: width * 0.72, y: height * 0.48))
                drape.addQuadCurve(
                    to: CGPoint(x: width * 0.80, y: height * 0.66),
                    control: CGPoint(x: width * 0.82, y: height * 0.54)
                )
                context.stroke(drape, with: .color(tint.opacity(0.85)), style: stroke)

            case .syrup:
                // Squat jar with a lid, and a spoon angled out of it.
                var jar = Path()
                jar.addRoundedRect(
                    in: CGRect(x: width * 0.16, y: height * 0.34, width: width * 0.46, height: height * 0.60),
                    cornerSize: CGSize(width: width * 0.10, height: width * 0.10)
                )
                context.stroke(jar, with: color, style: stroke)

                var lid = Path()
                lid.move(to: CGPoint(x: width * 0.22, y: height * 0.26))
                lid.addLine(to: CGPoint(x: width * 0.56, y: height * 0.26))
                context.stroke(lid, with: color, style: stroke)

                var neck = Path()
                neck.move(to: CGPoint(x: width * 0.16, y: height * 0.48))
                neck.addLine(to: CGPoint(x: width * 0.62, y: height * 0.48))
                context.stroke(neck, with: .color(tint.opacity(0.55)), style: stroke)

                var handle = Path()
                handle.move(to: CGPoint(x: width * 0.72, y: height * 0.94))
                handle.addLine(to: CGPoint(x: width * 0.84, y: height * 0.36))
                context.stroke(handle, with: color, style: stroke)

                var scoop = Path()
                scoop.addEllipse(in: CGRect(x: width * 0.74, y: height * 0.10, width: width * 0.22, height: height * 0.26))
                context.stroke(scoop, with: color, style: stroke)

            case .supplement:
                // A capsule and a scored tablet together: either one alone would claim a
                // specific dose form the data often doesn't specify.
                var capsule = Path()
                capsule.addRoundedRect(
                    in: CGRect(x: width * 0.34, y: height * 0.10, width: width * 0.58, height: height * 0.26),
                    cornerSize: CGSize(width: height * 0.13, height: height * 0.13)
                )
                let tilt = CGAffineTransform(translationX: width * 0.63, y: height * 0.23)
                    .rotated(by: -.pi / 6)
                    .translatedBy(x: -width * 0.63, y: -height * 0.23)
                context.stroke(capsule.applying(tilt), with: color, style: stroke)

                // Seam across the capsule's short axis, tilted with it.
                var seam = Path()
                seam.move(to: CGPoint(x: width * 0.63, y: height * 0.10))
                seam.addLine(to: CGPoint(x: width * 0.63, y: height * 0.36))
                context.stroke(seam.applying(tilt), with: .color(tint.opacity(0.6)), style: stroke)

                var tablet = Path()
                tablet.addEllipse(in: CGRect(x: width * 0.06, y: height * 0.48, width: width * 0.42, height: height * 0.42))
                context.stroke(tablet, with: color, style: stroke)

                var score = Path()
                score.move(to: CGPoint(x: width * 0.27, y: height * 0.53))
                score.addLine(to: CGPoint(x: width * 0.27, y: height * 0.85))
                context.stroke(score, with: .color(tint.opacity(0.6)), style: stroke)
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
