import CoreText
import SwiftUI
import UIKit

/// Grounded's type scale. Three bundled variable faces — Big Shoulders Display for the
/// wordmark and hero name, Big Shoulders Text for shelf and card titles, Public Sans for
/// reading and UI roles — expressed as named levels. Call the role modifiers (`.heroDisplay()`, `.bodyText()`, …) from
/// views rather than reaching for a raw size: each role owns its own weight,
/// letter-spacing, casing and line-height so the scale can't drift per screen.
enum Typography {
    private static let weightAxis: Int = 0x77676874 // 'wght'

    private static var isRegistered = false

    static func registerFonts() {
        guard !isRegistered else { return }
        isRegistered = true
        for name in ["BigShouldersDisplay", "BigShouldersText", "PublicSans"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("[Typography] missing bundled font: \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                print("[Typography] could not register \(name).ttf")
            }
        }
    }

    /// Big Shoulders Display ships with a Thin default instance, so the registered family
    /// name can come through either as the typographic family or with the style appended.
    /// Resolved once, after registration, against the families UIKit actually knows about.
    static let displayFamily: String = {
        let candidates = ["Big Shoulders Display", "Big Shoulders Display Thin"]
        let known = Set(UIFont.familyNames)
        return candidates.first(where: known.contains) ?? candidates[0]
    }()

    /// Big Shoulders *Text* — the tighter, lower-contrast companion cut, built for smaller
    /// sizes. Same Thin-default-instance caveat as the Display face.
    static let textFamily: String = {
        let candidates = ["Big Shoulders Text", "Big Shoulders Text Thin"]
        let known = Set(UIFont.familyNames)
        return candidates.first(where: known.contains) ?? candidates[0]
    }()

    static let bodyFamily = "Public Sans"

    private static func uiFont(family: String, size: CGFloat, weight: CGFloat) -> UIFont {
        let variations: [NSNumber: NSNumber] = [
            NSNumber(value: weightAxis): NSNumber(value: Double(weight)),
        ]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: family,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations,
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Display face. `weight` maps onto Big Shoulders Display's weight axis (100–900).
    static func display(_ size: CGFloat, _ weight: CGFloat = 700) -> Font {
        Font(uiFont(family: displayFamily, size: size, weight: weight))
    }

    /// Text face. `weight` maps onto Big Shoulders Text's weight axis (100–900).
    static func text(_ size: CGFloat, _ weight: CGFloat = 600) -> Font {
        Font(uiFont(family: textFamily, size: size, weight: weight))
    }

    /// Body face. `weight` maps onto Public Sans' weight axis (100–900).
    static func body(_ size: CGFloat, _ weight: CGFloat = 400) -> Font {
        Font(uiFont(family: bodyFamily, size: size, weight: weight))
    }

    // MARK: Metrics

    /// Linear interpolation across a role's size band, so a role's weight and tracking
    /// move together with its size instead of snapping between two hardcoded values.
    static func lerp(_ from: CGFloat, _ to: CGFloat, size: CGFloat, in band: ClosedRange<CGFloat>) -> CGFloat {
        guard band.upperBound > band.lowerBound else { return from }
        let clamped = min(max(size, band.lowerBound), band.upperBound)
        let t = (clamped - band.lowerBound) / (band.upperBound - band.lowerBound)
        return from + (to - from) * t
    }

    /// SwiftUI has no line-height property: `lineSpacing` adds space *between* lines on
    /// top of the font's own line height. Converting a CSS-style multiple therefore means
    /// subtracting that natural line height. Multiples at or below the font's own leading
    /// (the hero's 1.0, for instance) clamp to zero — SwiftUI cannot tighten past it.
    static func lineSpacing(
        size: CGFloat,
        multiple: CGFloat,
        family: String,
        weight: CGFloat
    ) -> CGFloat {
        max(0, size * multiple - uiFont(family: family, size: size, weight: weight).lineHeight)
    }
}

// MARK: - The seven levels

extension View {
    /// 1 — Hero Display. Big Shoulders Display 700–800, 34–42pt, all-caps, -1.5% to -2%
    /// tracking, line-height 1.0. Reserved for the wordmark and the Remedy Detail hero name.
    func heroDisplay(_ size: CGFloat = 38) -> some View {
        let band: ClosedRange<CGFloat> = 34...42
        let weight = Typography.lerp(700, 800, size: size, in: band)
        let tracking = Typography.lerp(-0.015, -0.020, size: size, in: band)
        return font(Typography.display(size, weight))
            .textCase(.uppercase)
            .tracking(size * tracking)
            .lineSpacing(
                Typography.lineSpacing(
                    size: size,
                    multiple: 1.0,
                    family: Typography.displayFamily,
                    weight: weight
                )
            )
    }

    /// 2 — Screen Headline. Big Shoulders Display 600–700, 24–28pt, all-caps, -1% tracking.
    /// Screen titles and shelf card names.
    func screenHeadline(_ size: CGFloat = 26) -> some View {
        let band: ClosedRange<CGFloat> = 24...28
        let weight = Typography.lerp(600, 700, size: size, in: band)
        return font(Typography.display(size, weight))
            .textCase(.uppercase)
            .tracking(size * -0.010)
            .lineSpacing(
                Typography.lineSpacing(
                    size: size,
                    multiple: 1.05,
                    family: Typography.displayFamily,
                    weight: weight
                )
            )
    }

    /// 3 — Section Eyebrow. Big Shoulders Display 400–500, 12–13pt, all-caps, +6% to +8%
    /// tracking, cream at ~68%. Every section label, and the category label above a remedy
    /// name. Pass `color` only where the eyebrow sits on a light surface.
    func sectionEyebrow(_ size: CGFloat = 13, color: Color = Theme.creamSecondary) -> some View {
        let band: ClosedRange<CGFloat> = 12...13
        let weight = Typography.lerp(400, 500, size: size, in: band)
        let tracking = Typography.lerp(0.06, 0.08, size: size, in: band)
        return font(Typography.display(size, weight))
            .textCase(.uppercase)
            .tracking(size * tracking)
            .foregroundStyle(color)
    }

    /// 3b — Catalog number. Big Shoulders Display 500–600, 11–13pt, all-caps, +10% tracking.
    /// The "No. 04" reference beside a category tag.
    ///
    /// Big Shoulders ships no true small-cap (`smcp`) feature, so this is the standing
    /// substitute: capitals set small and opened up with tracking, which is what small caps
    /// look like at this size anyway. Slightly wider tracking than the eyebrow so a short
    /// numeric string doesn't read as a cramped abbreviation.
    func catalogNumber(_ size: CGFloat = 12, color: Color = Theme.creamSecondary) -> some View {
        let weight = Typography.lerp(500, 600, size: size, in: 11...13)
        return font(Typography.display(size, weight))
            .textCase(.uppercase)
            .tracking(size * 0.10)
            .foregroundStyle(color)
    }

    /// 2b — Shelf header title. Big Shoulders *Text* 600–700, 24–28pt, all-caps, -1%
    /// tracking. Apothecary category shelf headers. Same metrics as `screenHeadline`, on
    /// the Text cut — the Display face stays reserved for the wordmark and hero name.
    func shelfTitle(_ size: CGFloat = 26) -> some View {
        let weight = Typography.lerp(600, 700, size: size, in: 24...28)
        return font(Typography.text(size, weight))
            .textCase(.uppercase)
            .tracking(size * -0.010)
            .lineSpacing(
                Typography.lineSpacing(
                    size: size,
                    multiple: 1.05,
                    family: Typography.textFamily,
                    weight: weight
                )
            )
    }

    /// 4 — List-item title. Big Shoulders *Text* 600, 16–17pt, all-caps, near-zero
    /// tracking. Remedy card titles in Apothecary shelves and search results.
    func listItemTitle(_ size: CGFloat = 17) -> some View {
        font(Typography.text(size, 600))
            .textCase(.uppercase)
            .tracking(0)
            .lineSpacing(
                Typography.lineSpacing(
                    size: size,
                    multiple: 1.1,
                    family: Typography.textFamily,
                    weight: 600
                )
            )
    }

    /// 5 — Body. Public Sans 400, 15–16pt, line-height 1.5–1.6. Chat text, ingredients,
    /// preparation steps — anything meant to be read in sentences.
    func bodyText(_ size: CGFloat = 15) -> some View {
        let multiple = Typography.lerp(1.5, 1.6, size: size, in: 15...16)
        return font(Typography.body(size, 400))
            .textCase(nil)
            .lineSpacing(
                Typography.lineSpacing(
                    size: size,
                    multiple: multiple,
                    family: Typography.bodyFamily,
                    weight: 400
                )
            )
    }

    /// 6 — UI / Button label. Public Sans 600, sentence case. Buttons, tab-bar labels and
    /// inline control labels. Deliberately *not* the display face.
    func uiLabel(_ size: CGFloat = 16, weight: CGFloat = 600) -> some View {
        font(Typography.body(size, weight))
            .textCase(nil)
    }

    /// 7 — Caption. Public Sans 400, 12–13pt, cream at ~68%. Captions, disclaimers,
    /// timestamps and counts. `italic` is opt-in for editorial asides.
    func captionText(
        _ size: CGFloat = 13,
        italic: Bool = false,
        color: Color = Theme.creamSecondary
    ) -> some View {
        font(Typography.body(size, 400))
            .textCase(nil)
            .italic(italic)
            .foregroundStyle(color)
            .lineSpacing(
                Typography.lineSpacing(
                    size: size,
                    multiple: 1.45,
                    family: Typography.bodyFamily,
                    weight: 400
                )
            )
    }
}
