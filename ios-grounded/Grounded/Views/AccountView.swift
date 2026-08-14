import SwiftUI

/// Destinations reachable from Account. A typed route rather than a `[Remedy]` path, now
/// that the stack pushes screens that aren't remedies.
private enum AccountRoute: Hashable {
    case remedy(Remedy)
    case editProfile
    case sourcing
    case help
    case about
}

struct AccountView: View {
    let onOpenRemedy: (Remedy) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(RemedyLibrary.self) private var library

    @State private var path: [AccountRoute] = []
    @State private var isConfirmingDeleteAll = false
    @State private var isConfirmingSignOut = false

    private var savedRemedies: [Remedy] {
        appModel.bookmarkedRemedyIDs.compactMap { library.remedy(id: $0) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    profileCard
                    trustSection
                    savedSection
                    updatesSection
                    privacySection
                    helpSection
                    signOutButton
                    disclaimerFootnote
                }
                .padding(.horizontal, 18)
                // Tab bar room comes from `clearsFloatingTabBar()` on the tab root; this is
                // only breathing space under the last row.
                .padding(.bottom, 28)
            }
            .navigationDestination(for: AccountRoute.self) { route in
                switch route {
                case .remedy(let remedy):
                    RemedyDetailView(remedy: remedy, onFollowUp: nil)
                case .editProfile:
                    EditProfileView()
                case .sourcing:
                    SourcingView()
                case .help:
                    HelpSupportView()
                case .about:
                    AboutView()
                }
            }
        }
        .tint(Theme.cream)
        .confirmationDialog(
            "Delete all stored health data?",
            isPresented: $isConfirmingDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) {
                appModel.deleteAllHealthData()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This removes the health data Grounded keeps on this device. Saved remedies stay on your shelf.")
        }
        .confirmationDialog("Sign out of Grounded?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { appModel.signOut() }
            Button("Stay signed in", role: .cancel) {}
        } message: {
            Text("You'll review the disclaimer and confirmations again next time.")
        }
    }

    private var header: some View {
        Text("Account")
            .screenHeadline(28)
            .foregroundStyle(Theme.cream)
            .padding(.top, 14)
    }

    private var profileCard: some View {
        Button {
            path.append(.editProfile)
        } label: {
            HStack(spacing: 16) {
                AvatarMark(washHex: appModel.profileAvatarWash, diameter: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(appModel.profileName)
                        .screenHeadline(24)
                        .foregroundStyle(Theme.cream)
                        .multilineTextAlignment(.leading)
                    Text(appModel.profileEmail)
                        .captionText(13)
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
        .accessibilityLabel("Edit profile. \(appModel.profileName), \(appModel.profileEmail)")
    }

    private var trustSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Trust & sourcing", trailing: nil)

            SettingsRow(
                title: "How we source",
                detail: "What the evidence tiers mean and how entries are vetted"
            ) {
                path.append(.sourcing)
            }
        }
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Saved remedies", trailing: "\(savedRemedies.count)")

            if savedRemedies.isEmpty {
                VStack(spacing: 8) {
                    Text("Your shelf is empty")
                        .screenHeadline(24)
                        .foregroundStyle(Theme.cream)
                    Text("Bookmark a remedy in the Apothecary and it will sit here.")
                        .captionText(13)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .fill(Theme.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
            } else {
                ForEach(savedRemedies) { remedy in
                    RemedyListRow(remedy: remedy) { path.append(.remedy(remedy)) }
                }
            }
        }
    }

    /// The three update channels. Each toggle writes straight through to `AppModel`, which
    /// is also what the Updates inbox filters on — so switching one off empties that stream
    /// from the inbox rather than just recording a preference for later.
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Updates", trailing: nil)

            ForEach(UpdateChannel.allCases) { channel in
                SettingsToggleRow(
                    title: channel.title,
                    detail: channel.detail,
                    isOn: Binding(
                        get: { appModel.isChannelEnabled(channel) },
                        set: { appModel.setChannel(channel, enabled: $0) }
                    )
                )
            }

            Text("These control what appears in the Updates inbox, reachable from the bell in Chat. Grounded doesn't send push notifications yet.")
                .captionText(12, color: Theme.creamFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Help & about", trailing: nil)

            SettingsRow(
                title: "Help & Support",
                detail: "Common questions, what the scanner can't do, and how to report a problem"
            ) {
                path.append(.help)
            }

            SettingsRow(
                title: "About Grounded",
                detail: "Version, legal documents, and the disclaimer you agreed to"
            ) {
                path.append(.about)
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Privacy & data", trailing: nil)

            VStack(alignment: .leading, spacing: 14) {
                Text("Health data Grounded stores on this device")
                    .uiLabel(15)
                    .foregroundStyle(Theme.cream)

                if appModel.storedHealthItems.isEmpty {
                    Text("No health data is currently stored.")
                        .captionText(13)
                } else {
                    ForEach(appModel.storedHealthItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.label)
                                    .bodyText(15)
                                    .foregroundStyle(Theme.cream)
                                Text(item.detail)
                                    .captionText(12)
                            }
                            Spacer(minLength: 8)
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                                    appModel.deleteHealthItem(item)
                                }
                            } label: {
                                Text("Delete")
                                    .uiLabel(13)
                                    .foregroundStyle(Theme.cream)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background {
                                        Capsule().fill(Theme.cream.opacity(0.08))
                                    }
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                        .padding(.vertical, 2)
                    }
                }

                Divider().overlay(Theme.hairline)

                Text(appModel.didConsentToHealthData
                     ? "You agreed to health-data collection during onboarding, and confirmed you are 13 or older."
                     : "Health-data collection consent is not currently on file.")
                    .captionText(12)
                    .fixedSize(horizontal: false, vertical: true)

                QuietButton(title: "Delete all stored health data", systemImage: "trash") {
                    isConfirmingDeleteAll = true
                }
            }
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

    private var signOutButton: some View {
        QuietButton(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right") {
            isConfirmingSignOut = true
        }
    }

    private var disclaimerFootnote: some View {
        Text("Grounded shares educational information from curated, cited sources. It is not medical advice and does not replace a clinician. In an emergency, call 911.")
            .captionText(12, color: Theme.creamFaint)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private func sectionTitle(_ title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .sectionEyebrow()
            Spacer()
            if let trailing {
                Text(trailing)
                    .uiLabel(12)
                    .foregroundStyle(Theme.creamMuted)
            }
        }
    }
}
