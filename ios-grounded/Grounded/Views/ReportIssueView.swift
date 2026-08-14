import SwiftUI

/// "Report an issue with this remedy", presented as a sheet from Remedy Detail and from
/// Help & Support.
///
/// There is no reporting endpoint yet. Rather than a form that silently discards what the
/// user wrote, or a fake "thanks, we got it" confirmation, the report is stored on-device and
/// the screen says exactly that both before and after submitting.
struct ReportIssueView: View {
    /// Pre-selected when opened from a remedy screen. Nil when opened from Help & Support,
    /// where the user picks the entry first.
    let remedy: Remedy?

    @Environment(AppModel.self) private var appModel
    @Environment(RemedyLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRemedyID: String?
    @State private var reason: IssueReport.Reason = .inaccurate
    @State private var note: String = ""
    @State private var didSubmit = false

    private var chosenRemedy: Remedy? {
        if let remedy { return remedy }
        return selectedRemedyID.flatMap { library.remedy(id: $0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphericBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if didSubmit {
                            confirmation
                        } else {
                            header
                            if remedy == nil {
                                remedyPicker
                            }
                            reasonPicker
                            noteField
                            submit
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(didSubmit ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(Theme.cream)
                }
            }
        }
        .tint(Theme.cream)
        .presentationBackground(Theme.background)
    }

    // MARK: Form

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Report an issue")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)
            if let chosenRemedy {
                Text(chosenRemedy.name)
                    .captionText(13, color: Theme.creamMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Sourcing corrections are the most useful thing you can send. If a citation is wrong, a safety warning is missing, or a preparation doesn't match its source, say so here.")
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }

    private var remedyPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which entry")
                .sectionEyebrow()

            // A menu rather than 20 rows: the list is long enough to bury the rest of the
            // form, and most people arrive here already knowing the entry.
            Menu {
                ForEach(library.remedies) { item in
                    Button(item.name) { selectedRemedyID = item.id }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(chosenRemedy?.name ?? "Choose a remedy")
                        .uiLabel(15)
                        .foregroundStyle(chosenRemedy == nil ? Theme.creamMuted : Theme.cream)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 10)
                    UIChromeIcon(systemName: "chevron.up.chevron.down", size: 12, color: Theme.creamFaint)
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
        }
    }

    private var reasonPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's wrong")
                .sectionEyebrow()

            VStack(spacing: 0) {
                ForEach(Array(IssueReport.Reason.allCases.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().overlay(Theme.hairline).padding(.horizontal, 18)
                    }
                    Button {
                        reason = item
                    } label: {
                        HStack(spacing: 12) {
                            Text(item.rawValue)
                                .bodyText(15)
                                .foregroundStyle(Theme.cream.opacity(reason == item ? 1 : 0.78))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 10)
                            Circle()
                                .strokeBorder(
                                    reason == item ? Theme.cream : Theme.cream.opacity(0.28),
                                    lineWidth: Theme.iconStroke
                                )
                                .frame(width: 18, height: 18)
                                .overlay {
                                    if reason == item {
                                        Circle().fill(Theme.cream).frame(width: 8, height: 8)
                                    }
                                }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(SoftPressStyle(scale: 0.995))
                    .accessibilityAddTraits(reason == item ? [.isSelected] : [])
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
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details (optional)")
                .sectionEyebrow()

            TextField("What did you find?", text: $note, axis: .vertical)
                .bodyText(15)
                .foregroundStyle(Theme.cream)
                .tint(Theme.cream)
                .lineLimit(4...8)
                .padding(18)
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

    private var submit: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Save this report", isEnabled: chosenRemedy != nil) {
                guard let chosenRemedy else { return }
                appModel.submitIssueReport(
                    remedyID: chosenRemedy.id,
                    remedyName: chosenRemedy.name,
                    reason: reason,
                    note: note
                )
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    didSubmit = true
                }
            }

            Text("Reports are kept on this device. Grounded has no reporting server yet, so nothing is sent anywhere — this queue is here so what you write isn't lost when it goes live.")
                .captionText(12, color: Theme.creamFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: Confirmation

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 14) {
            BotanicalSprig(lineWidth: 1)
                .frame(width: 48, height: 66)
                .opacity(0.5)
            Text("Saved on this device")
                .screenHeadline(24)
                .foregroundStyle(Theme.cream)
            Text("Your report is stored locally and has not been sent — there's nowhere to send it yet. You can see how many reports are queued in Help & Support.")
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Close") { dismiss() }
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
        .padding(.top, 20)
        .transition(.opacity.combined(with: .offset(y: 10)))
    }
}
