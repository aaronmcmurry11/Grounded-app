import SwiftUI

/// The Updates inbox, opened from the chat-header bell.
///
/// Content is filtered by the three channel toggles in Account, so those switches have a
/// visible consequence here rather than being decorative. Two of the three are off by
/// default, which means a new user sees remedy updates only — the empty state names the
/// channels that are switched off rather than pretending there's nothing to show.
struct UpdatesView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RemedyLibrary.self) private var library

    @State private var feed = UpdatesFeed()
    /// Snapshotted when the screen opens, *before* the read marker moves — otherwise
    /// marking the inbox read would erase the unread styling in the same frame the user
    /// arrived to look at it.
    @State private var unreadIDs: Set<String> = []
    @State private var path: [Remedy] = []

    private var visibleEntries: [AppUpdate] {
        feed.entries { appModel.isChannelEnabled($0) }
    }

    private var mutedChannels: [UpdateChannel] {
        UpdateChannel.allCases.filter { !appModel.isChannelEnabled($0) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AtmosphericBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header

                        if feed.isLoading {
                            ForEach(0..<3, id: \.self) { _ in SkeletonCard() }
                        } else if feed.loadFailed {
                            failureCard
                        } else if visibleEntries.isEmpty {
                            emptyState
                        } else {
                            ForEach(visibleEntries) { entry in
                                UpdateCard(
                                    entry: entry,
                                    isUnread: unreadIDs.contains(entry.id),
                                    remedy: entry.remedyID.flatMap { library.remedy(id: $0) },
                                    onOpenRemedy: { path.append($0) }
                                )
                            }
                            if !mutedChannels.isEmpty {
                                mutedNote
                            }
                            footnote
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Remedy.self) { remedy in
                RemedyDetailView(remedy: remedy, onFollowUp: nil)
            }
        }
        .tint(Theme.cream)
        .presentationBackground(Theme.background)
        .task {
            await feed.loadIfNeeded()
            unreadIDs = Set(
                feed.entries { appModel.isChannelEnabled($0) }
                    .filter { entry in
                        guard let lastOpened = appModel.updatesLastOpenedAt else { return true }
                        return entry.date > lastOpened
                    }
                    .map(\.id)
            )
            appModel.markUpdatesRead()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Updates")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)
            Text(unreadIDs.isEmpty
                 ? "Changes to the library and to the app"
                 : "\(unreadIDs.count) new since you last looked")
                .captionText(12)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            BotanicalSprig(lineWidth: 1)
                .frame(width: 54, height: 74)
                .opacity(0.5)
            Text("Nothing new")
                .screenHeadline(24)
                .foregroundStyle(Theme.cream)
            Text(mutedChannels.count == UpdateChannel.allCases.count
                 ? "All three update types are switched off in Account, so nothing is coming through."
                 : "No updates have come through on the channels you have switched on.")
                .captionText(13)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 18)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }

    private var failureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Updates couldn't be opened")
                .uiLabel(15)
                .foregroundStyle(Theme.cream)
            Text("Nothing is missing from the library itself — only this list failed to load.")
                .captionText(13)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
    }

    /// Names what's switched off, so a short inbox doesn't get mistaken for a quiet library.
    private var mutedNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Switched off")
                .sectionEyebrow(12)
            Text(mutedChannels.map(\.title).joined(separator: " · "))
                .captionText(12)
                .fixedSize(horizontal: false, vertical: true)
            Text("Turn these on in Account → Updates.")
                .captionText(12, color: Theme.creamFaint)
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
        .padding(.top, 6)
    }

    private var footnote: some View {
        Text("These entries are a fixed sample written to show the format. Updates aren't yet generated from live changes to the library, and Grounded doesn't send push notifications.")
            .captionText(12, color: Theme.creamFaint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }
}

// MARK: - Card

private struct UpdateCard: View {
    let entry: AppUpdate
    let isUnread: Bool
    let remedy: Remedy?
    let onOpenRemedy: (Remedy) -> Void

    @Environment(AppModel.self) private var appModel

    private var dateLabel: String {
        entry.date.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        Group {
            if let remedy {
                Button {
                    onOpenRemedy(remedy)
                } label: {
                    content(showsChevron: true)
                }
                .buttonStyle(SoftPressStyle(scale: 0.99))
                .accessibilityLabel("\(entry.channel.inboxLabel). \(entry.title). \(entry.body)")
                .accessibilityHint("Opens \(remedy.name)")
            } else {
                // No destination, so no chevron and no button — a row that looks tappable and
                // isn't is worse than a plain card.
                content(showsChevron: false)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func content(showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if isUnread {
                    Circle()
                        .fill(Theme.cream)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Unread")
                }
                Text(entry.channel.inboxLabel)
                    .sectionEyebrow(12)
                Spacer(minLength: 8)
                Text(dateLabel)
                    .captionText(11, color: Theme.creamFaint)
                if showsChevron {
                    UIChromeIcon(systemName: "chevron.right", size: 11, color: Theme.creamFaint)
                }
            }

            Text(entry.title)
                .listItemTitle(16)
                .foregroundStyle(Theme.cream)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(entry.body)
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.84))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let remedy, appModel.isBookmarked(remedy) {
                Text("On your shelf")
                    .captionText(11, color: Theme.creamFaint)
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
                // Unread carries a slightly brighter edge rather than a filled background:
                // the read/unread difference should be findable, not loud.
                .strokeBorder(isUnread ? Theme.cream.opacity(0.26) : Theme.hairline, lineWidth: 1)
        }
        .contentShape(.rect)
    }
}
