import SwiftUI

/// Edit Profile: display name and avatar wash. Email is shown read-only — changing it needs
/// an email re-verification flow, which is separate work.
struct EditProfileView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RemedyLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var draftName: String = ""
    @State private var draftWash: String = ""
    @State private var didLoadDraft = false
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        trimmedName != appModel.profileName || draftWash != appModel.profileAvatarWash
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && hasChanges
    }

    /// The four washes already in use on the shelves, in seed-file order. Read from the
    /// library rather than hardcoded, so the picker follows the palette if a shelf changes.
    private var washes: [String] {
        library.categories.map(\.colorHex)
    }

    var body: some View {
        ZStack {
            AtmosphericBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    nameSection
                    avatarSection
                    emailSection
                    PrimaryButton(title: "Save changes", isEnabled: canSave) {
                        save()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // Loaded once, so the draft isn't clobbered if the view re-appears mid-edit.
            guard !didLoadDraft else { return }
            draftName = appModel.profileName
            draftWash = appModel.profileAvatarWash
            didLoadDraft = true
        }
    }

    // MARK: Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit profile")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)

            HStack(spacing: 16) {
                AvatarMark(washHex: draftWash, diameter: 62)
                VStack(alignment: .leading, spacing: 3) {
                    // Live preview: the card reads exactly as Account will once saved.
                    Text(trimmedName.isEmpty ? "Your name" : trimmedName)
                        .screenHeadline(24)
                        .foregroundStyle(trimmedName.isEmpty ? Theme.creamFaint : Theme.cream)
                    Text(appModel.profileEmail)
                        .captionText(13)
                }
                Spacer(minLength: 0)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: draftWash)
        }
        .padding(.top, 8)
    }

    // MARK: Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display name")
                .sectionEyebrow()

            TextField("Display name", text: $draftName)
                .bodyText(16)
                .foregroundStyle(Theme.cream)
                .tint(Theme.cream)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isNameFocused)
                .onSubmit { if canSave { save() } }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .fill(Theme.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .strokeBorder(
                            isNameFocused ? Theme.cream.opacity(0.38) : Theme.hairline,
                            lineWidth: isNameFocused ? 1.6 : 1
                        )
                }
                .animation(.easeOut(duration: 0.18), value: isNameFocused)

            Text(trimmedName.isEmpty
                 ? "A display name is required."
                 : "This is the name shown on your account. It is stored on this device.")
                .captionText(12)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Avatar

    private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avatar")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 14) {
                if washes.isEmpty {
                    // Washes come from the remedy library; skeletons hold the row's shape
                    // rather than a spinner if it hasn't arrived.
                    HStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonBar(width: 58, height: 58)
                        }
                    }
                } else {
                    HStack(spacing: 14) {
                        ForEach(washes, id: \.self) { hex in
                            Button {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    draftWash = hex
                                }
                            } label: {
                                AvatarMark(
                                    washHex: hex,
                                    diameter: 58,
                                    isSelected: draftWash == hex
                                )
                                .frame(width: 60, height: 60)
                                .contentShape(.circle)
                            }
                            .buttonStyle(SoftPressStyle(scale: 0.93))
                            .accessibilityLabel(accessibilityName(for: hex))
                            .accessibilityAddTraits(draftWash == hex ? [.isSelected] : [])
                        }
                        Spacer(minLength: 0)
                    }
                }

                Text("The leaf mark on one of the four shelf washes. Photo uploads aren't supported.")
                    .captionText(12)
                    .fixedSize(horizontal: false, vertical: true)
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
        }
    }

    /// Names the wash by its shelf, so the picker isn't four unlabelled swatches to
    /// VoiceOver users.
    private func accessibilityName(for hex: String) -> String {
        let shelf = library.categories.first { $0.colorHex == hex }?.name ?? "Category"
        return "\(shelf) wash"
    }

    // MARK: Email

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Email")
                .sectionEyebrow()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(appModel.profileEmail)
                        .bodyText(16)
                        .foregroundStyle(Theme.creamMuted)
                    Spacer(minLength: 8)
                    UIChromeIcon(systemName: "lock", size: 13)
                }
                Text("Your email can't be changed here yet — a new address has to be re-verified before it takes effect.")
                    .captionText(12)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.cream.opacity(0.03))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
    }

    private func save() {
        isNameFocused = false
        guard appModel.updateProfileName(draftName) else { return }
        appModel.profileAvatarWash = draftWash
        dismiss()
    }
}
