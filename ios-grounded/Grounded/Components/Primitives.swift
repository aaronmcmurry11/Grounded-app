import SwiftUI
import UIKit

/// Gentle scale + opacity feedback on press, with a light haptic tick.
struct SoftPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Cream, fully rounded primary CTA.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    /// Tier C glyph, used instead of `systemImage` where the mark belongs to the brand set
    /// (bookmark, chat) rather than to plain chrome.
    var glyph: LineGlyph?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .uiLabel(16)
                if let glyph {
                    LineIcon(glyph: glyph, size: 17, tint: Theme.onCream)
                } else if let systemImage {
                    UIChromeIcon(systemName: systemImage, size: 14, color: Theme.onCream)
                }
            }
            .foregroundStyle(Theme.onCream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background {
                Capsule(style: .continuous)
                    .fill(Theme.cream)
            }
            .opacity(isEnabled ? 1 : 0.28)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!isEnabled)
    }
}

/// Quiet secondary action — outline only, never colored.
struct QuietButton: View {
    let title: String
    var systemImage: String?
    var glyph: LineGlyph?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let glyph {
                    LineIcon(glyph: glyph, size: 16, tint: Theme.cream)
                } else if let systemImage {
                    UIChromeIcon(systemName: systemImage, size: 13, color: Theme.cream)
                }
                Text(title)
                    .uiLabel(15)
            }
            .foregroundStyle(Theme.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                Capsule(style: .continuous)
                    .fill(Theme.cream.opacity(0.06))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Theme.cream.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(SoftPressStyle())
    }
}

/// Rounded navigation row: title, optional detail line, optional leading Tier C glyph, and
/// a Tier D trailing chevron. The standard "tap to go deeper" affordance in Account.
struct SettingsRow<Leading: View>: View {
    let title: String
    var detail: String?
    var leading: Leading
    let action: () -> Void

    init(
        title: String,
        detail: String? = nil,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.leading = leading()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                leading
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .uiLabel(15)
                        .foregroundStyle(Theme.cream)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .captionText(12)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 10)
                UIChromeIcon(systemName: "chevron.right", size: 13, color: Theme.creamFaint)
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
            .contentShape(.rect)
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }
}

/// Rounded settings row carrying a switch instead of a chevron. Same surface, radius and
/// hairline as `SettingsRow`, so a toggle row and a navigation row read as one family.
struct SettingsToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        // A `Toggle` with a real label, not a Button wrapping a decorative switch — the
        // system control brings its own VoiceOver traits, keyboard handling and animation.
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .uiLabel(15)
                    .foregroundStyle(Theme.cream)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .captionText(12)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Cream, not a system accent — the palette has no blue in it.
        .tint(Theme.cream)
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

/// Rounded row that expands in place to reveal prose. Used for the Help & Support FAQ, where
/// pushing a whole screen per question would bury short answers behind navigation.
struct ExpandableRow<Content: View>: View {
    let title: String
    var isInitiallyExpanded: Bool = false
    @ViewBuilder var content: () -> Content

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text(title)
                        .uiLabel(15)
                        .foregroundStyle(Theme.cream)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 10)
                    UIChromeIcon(systemName: "chevron.down", size: 12, color: Theme.creamFaint)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, 2)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(SoftPressStyle(scale: 0.995))
            .accessibilityHint(isExpanded ? "Collapses the answer" : "Expands the answer")

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .onAppear {
            if isInitiallyExpanded { isExpanded = true }
        }
    }
}

/// Atmospheric background: near-black with two soft, very low-opacity warm glows.
struct AtmosphericBackground: View {
    var body: some View {
        Theme.background
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [Theme.cream.opacity(0.055), .clear],
                    center: .top,
                    startRadius: 4,
                    endRadius: 420
                )
            }
            .overlay(alignment: .bottomTrailing) {
                RadialGradient(
                    colors: [Color(hex: 0x5C4423).opacity(0.20), .clear],
                    center: .bottomTrailing,
                    startRadius: 8,
                    endRadius: 380
                )
            }
            .ignoresSafeArea()
    }
}

/// Skeleton-style loading placeholder — used instead of spinners.
struct SkeletonBar: View {
    var width: CGFloat?
    var height: CGFloat = 12

    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Theme.cream.opacity(shimmer ? 0.16 : 0.07))
            .frame(width: width, height: height)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
    }
}

/// Skeleton stand-in shaped like a real content row, used while a feed loads. Matching the
/// loaded row's height and radius keeps the list from jumping when content arrives.
struct SkeletonCard: View {
    var lines: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonBar(width: 86, height: 10)
            SkeletonBar(height: 14)
            ForEach(0..<max(0, lines), id: \.self) { index in
                SkeletonBar(width: index == lines - 1 ? 180 : nil, height: 10)
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
        .accessibilityLabel("Loading")
    }
}

/// Tier A — fine-line woodcut botanical sprig, drawn with strokes rather than a flat icon.
/// Hairlines only, no hatching: engraving density collapses into mud at cream-on-dark.
struct BotanicalSprig: View {
    var lineWidth: CGFloat = 1.2
    var tint: Color = Theme.cream

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let midX = width / 2

            var stem = Path()
            stem.move(to: CGPoint(x: midX, y: height))
            stem.addCurve(
                to: CGPoint(x: midX, y: height * 0.12),
                control1: CGPoint(x: midX - width * 0.06, y: height * 0.7),
                control2: CGPoint(x: midX + width * 0.05, y: height * 0.4)
            )
            context.stroke(stem, with: .color(tint.opacity(0.9)), lineWidth: lineWidth)

            for index in 0..<5 {
                let progress = 0.2 + Double(index) * 0.14
                let y = height * (1 - progress)
                let span = width * (0.34 - Double(index) * 0.045)
                for direction in [-1.0, 1.0] {
                    var leaf = Path()
                    let tip = CGPoint(x: midX + span * direction, y: y - height * 0.09)
                    leaf.move(to: CGPoint(x: midX, y: y))
                    leaf.addQuadCurve(to: tip, control: CGPoint(x: midX + span * 0.5 * direction, y: y - height * 0.02))
                    leaf.addQuadCurve(
                        to: CGPoint(x: midX, y: y),
                        control: CGPoint(x: midX + span * 0.42 * direction, y: y - height * 0.11)
                    )
                    context.stroke(leaf, with: .color(tint.opacity(0.75)), lineWidth: lineWidth)

                    var vein = Path()
                    vein.move(to: CGPoint(x: midX, y: y))
                    vein.addLine(to: tip)
                    context.stroke(vein, with: .color(tint.opacity(0.35)), lineWidth: lineWidth * 0.6)
                }
            }

            var root = Path()
            root.move(to: CGPoint(x: midX, y: height))
            root.addQuadCurve(to: CGPoint(x: midX - width * 0.16, y: height * 1.0), control: CGPoint(x: midX - width * 0.1, y: height * 0.94))
            context.stroke(root, with: .color(tint.opacity(0.4)), lineWidth: lineWidth * 0.7)
        }
        .allowsHitTesting(false)
    }
}
