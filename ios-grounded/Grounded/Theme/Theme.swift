import SwiftUI

/// Grounded's finalized design tokens — "Atmospheric Noir" (dark mode only for v1).
enum Theme {
    // MARK: Color tokens

    /// Near-black app background, softened from pure black.
    static let background = Color(hex: 0x141416)
    /// Slightly lifted surface for raised cards.
    static let surface = Color(hex: 0x1C1C1F)
    /// Floating / interactive elevation.
    static let surfaceRaised = Color(hex: 0x232327)
    /// Warm cream — body text on dark, and all primary CTAs.
    static let cream = Color(hex: 0xF1EEE3)
    /// Near-black text used on cream buttons.
    static let onCream = Color(hex: 0x1D1B16)
    /// Reserved exclusively for the emergency banner and contraindication warnings.
    static let safetyRed = Color(hex: 0xC81E1E)

    /// Secondary reading colour for eyebrows and captions.
    static var creamSecondary: Color { cream.opacity(0.68) }
    static var creamMuted: Color { cream.opacity(0.62) }
    static var creamFaint: Color { cream.opacity(0.34) }
    static var hairline: Color { cream.opacity(0.10) }

    // MARK: Iconography

    /// Tier C stroke weight — uniform across every functional icon.
    static let iconStroke: CGFloat = 1.6
    /// Selected/active Tier C weight. Stays inside the 1.5–2pt band.
    static let iconStrokeEmphasized: CGFloat = 2.0
    /// Tier D symbols carry no stroke width of their own, so weight is the only lever for
    /// matching them optically to the Tier C set.
    static let chromeIconWeight: Font.Weight = .medium

    // MARK: Floating tab bar

    /// Height of the tab bar capsule: 52pt buttons plus its own 6pt padding, top and bottom.
    static let tabBarHeight: CGFloat = 64
    /// Bottom room every screen sitting behind the tab bar must reserve — the capsule plus a
    /// visible gap, so a primary button never ends up flush against it.
    static let tabBarClearance: CGFloat = tabBarHeight + 24

    // MARK: Radii

    static let radiusSmall: CGFloat = 14
    static let radiusCard: CGFloat = 24
    static let radiusLarge: CGFloat = 32

    // MARK: Category colors (looked up from the seed data, with a safe fallback)

    static func categoryColor(_ hex: String?) -> Color {
        guard let hex, let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) else {
            return surfaceRaised
        }
        return Color(hex: value)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Floating tab bar clearance

extension View {
    /// Reserves room for the floating tab bar. The bar is a `ZStack` overlay, so it adds no
    /// safe area of its own and content would otherwise scroll underneath it with no way to
    /// bring the last element into view.
    ///
    /// Apply this to a tab's root, *outside* its `NavigationStack` — the inset shrinks the
    /// stack's safe area, which every pushed destination then inherits automatically. Screens
    /// must not re-add it locally, or the padding doubles up.
    func clearsFloatingTabBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: Theme.tabBarClearance)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Elevation

extension View {
    /// Soft, diffused ambient elevation. Never a harsh drop shadow.
    func ambientElevation(_ level: Elevation = .raised) -> some View {
        switch level {
        case .flat:
            return shadow(color: .clear, radius: 0)
        case .raised:
            return shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 8)
        case .floating:
            return shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 14)
        }
    }
}

enum Elevation {
    case flat, raised, floating
}
