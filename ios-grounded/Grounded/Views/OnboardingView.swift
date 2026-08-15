import SwiftUI

/// Welcome flow. The disclaimer, health-data consent and age affirmation are all
/// required, visible steps — none of them are skippable.
struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel

    @State private var step: Int = 0
    @State private var consentChecked = false
    @State private var ageChecked = false

    var body: some View {
        ZStack {
            AtmosphericBackground()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                if step == 0 {
                    disclaimerCard
                        .transition(.opacity.combined(with: .offset(y: 14)))
                } else {
                    consentCard
                        .transition(.opacity.combined(with: .offset(y: 14)))
                }
                Spacer(minLength: 16)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
    }

    private var header: some View {
        VStack(spacing: 14) {
            BotanicalSprig(lineWidth: 1.1)
                .frame(width: 86, height: 118)
                .padding(.top, 24)

            Text("Grounded")
                .heroDisplay(42)
                .foregroundStyle(Theme.cream)

            Text("Traditional, herbal and ancestral remedy knowledge — curated, cited, and plainly explained.")
                .bodyText(15)
                .foregroundStyle(Theme.creamMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("Before you begin")
                    .screenHeadline(24)
            } icon: {
                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.cream)

            VStack(alignment: .leading, spacing: 12) {
                disclaimerRow("Grounded shares educational information drawn from a curated, cited source base.")
                disclaimerRow("It is not medical advice and does not diagnose, treat or replace care from a qualified professional.")
                disclaimerRow("Always speak with a clinician about your symptoms and any medication or supplement you take.")
                disclaimerRow("In an emergency, call 911 or your local emergency number.", emphasised: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .ambientElevation(.raised)
    }

    private func disclaimerRow(_ text: String, emphasised: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(emphasised ? Theme.safetyRed : Theme.creamFaint)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .bodyText(15)
                .foregroundStyle(emphasised ? Theme.cream : Theme.cream.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your agreement")
                .screenHeadline(24)
                .foregroundStyle(Theme.cream)

            ConsentToggleRow(
                isOn: $consentChecked,
                title: "I agree to health-data collection",
                detail: "Grounded stores the symptom topics you ask about and the remedies you save, so it can keep your shelf and history. You can view or delete this at any time in Account."
            )
            .accessibilityIdentifier("onboarding.consentHealth")

            Divider().overlay(Theme.hairline)

            ConsentToggleRow(
                isOn: $ageChecked,
                title: "I am 13 years of age or older",
                detail: "Grounded is not intended for children under 13. This is your own confirmation, not a verification."
            )
            .accessibilityIdentifier("onboarding.consentAge")
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .ambientElevation(.raised)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if step == 0 {
                PrimaryButton(title: "I understand", systemImage: "arrow.right") {
                    step = 1
                }
                .accessibilityIdentifier("onboarding.understand")
            } else {
                PrimaryButton(title: "Get started", systemImage: "arrow.right", isEnabled: consentChecked && ageChecked) {
                    appModel.didConsentToHealthData = consentChecked
                    appModel.didAffirmAge = ageChecked
                    // Recorded here rather than on first launch: the date has to be the
                    // moment consent was actually given, since Account reprints it.
                    appModel.consentRecordedAt = .now
                    appModel.hasCompletedOnboarding = true
                }
                .accessibilityIdentifier("onboarding.getStarted")
                Text(consentChecked && ageChecked
                     ? "You can withdraw consent and delete your data from Account."
                     : "Both confirmations are required to continue.")
                    .captionText(12)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Theme.cream : Theme.creamFaint)
                        .frame(width: index == step ? 22 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
        }
    }
}

private struct ConsentToggleRow: View {
    @Binding var isOn: Bool
    let title: String
    let detail: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isOn ? Theme.cream : Color.clear)
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isOn ? Theme.cream : Theme.cream.opacity(0.3), lineWidth: 1.4)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.onCream)
                    }
                }
                .frame(width: 26, height: 26)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .uiLabel(15)
                        .foregroundStyle(Theme.cream)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .captionText(13)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
