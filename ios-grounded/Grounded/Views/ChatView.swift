import SwiftUI

struct ChatView: View {
    @Bindable var chat: ChatModel
    @Environment(RemedyLibrary.self) private var library
    @Environment(AppModel.self) private var appModel

    @State private var detailRemedy: Remedy?
    @State private var isShowingUpdates = false
    /// Owned by the view rather than the chat model: the unread count belongs to the inbox,
    /// and the header is the only thing that needs it.
    @State private var updatesFeed = UpdatesFeed()
    /// Focus lives here (not inside the composer) so the composer can be rebuilt on
    /// every new message without the field losing its focus state.
    @FocusState private var isComposerFocused: Bool
    @State private var keyboard = KeyboardObserver()

    /// Driven by the measured keyboard frame, never by focus state: focus flips the
    /// instant you tap, while the keyboard is still animating up.
    private var composerClearance: CGFloat {
        keyboard.isVisible ? keyboard.overlap + 8 : Theme.tabBarClearance
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatHeader(unreadUpdates: unreadUpdates) { isShowingUpdates = true }

            SafetyBanner(result: activeSafetyBanner)
                .padding(.horizontal, 18)
                .padding(.bottom, activeSafetyBanner != nil ? 12 : 0)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(chat.messages) { message in
                            MessageRow(message: message) { remedy in
                                detailRemedy = remedy
                            }
                            .id(message.id)
                        }
                        if chat.isThinking {
                            ThinkingBubble()
                                .id("thinking")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chat.messages.count) { _, _ in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        proxy.scrollTo(chat.messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
        // The composer is pinned above the thread and lifted by the measured keyboard
        // overlap. Automatic avoidance is switched off so exactly one thing moves it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposer(chat: chat, isFocused: $isComposerFocused)
                // Clears the floating tab bar while the keyboard is down.
                .padding(.bottom, composerClearance)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $detailRemedy) { (remedy: Remedy) in
            RemedyDetailSheet(remedy: remedy)
        }
        .sheet(isPresented: $isShowingUpdates) {
            UpdatesView()
        }
        .task {
            await updatesFeed.loadIfNeeded()
        }
    }

    private var unreadUpdates: Int {
        updatesFeed.unreadCount(since: appModel.updatesLastOpenedAt) { appModel.isChannelEnabled($0) }
    }

    /// A real triage hit always wins; the Help & Support preview toggle is a fallback so
    /// that screen can still demonstrate the banner with no real trigger active.
    private var activeSafetyBanner: TriageResult? {
        chat.activeTriageResult ?? (appModel.isSafetyBannerPreviewActive ? .previewSample : nil)
    }
}

// MARK: - Header

private struct ChatHeader: View {
    let unreadUpdates: Int
    let onOpenUpdates: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grounded")
                    .heroDisplay(34)
                    .foregroundStyle(Theme.cream)
                Text("Educational information, not medical advice")
                    .captionText(12)
            }
            Spacer()
            Button(action: onOpenUpdates) {
                // Tier C now: the header's one icon was the last SF Symbol sitting beside a
                // drawn tab bar, so it's a stroked glyph at the shared weight. The unread
                // badge is composed on top rather than drawn into the glyph, which is why
                // `bell.badge` wasn't the right shape to copy.
                LineIcon(glyph: .bell, size: 20, tint: Theme.cream.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle().fill(Theme.cream.opacity(0.06))
                    }
                    .overlay(alignment: .topTrailing) {
                        if unreadUpdates > 0 {
                            Circle()
                                .fill(Theme.cream)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    // A ring in the background colour separates the dot from
                                    // the bell's own stroke without needing a gap in the art.
                                    Circle().strokeBorder(Theme.background, lineWidth: 1.5)
                                }
                                .padding(.trailing, 9)
                                .padding(.top, 9)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: unreadUpdates)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(unreadUpdates > 0 ? "Updates, \(unreadUpdates) unread" : "Updates")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }
}

/// Surfaces above the thread whenever the deterministic red-flag layer (see
/// `RedFlagTriage.swift`) fires on the most recent message — copy is per-category, not
/// generic, so the resource pointed to actually matches what was described (911 vs.
/// Poison Control vs. 988).
struct SafetyBanner: View {
    let result: TriageResult?

    var body: some View {
        Group {
            if let result {
                HStack(alignment: .top, spacing: 12) {
                    // Shape and color untouched — weight harmonized to the chrome token.
                    UIChromeIcon(
                        systemName: "exclamationmark.triangle.fill",
                        size: 18,
                        weight: .semibold,
                        color: Theme.cream
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .screenHeadline(24)
                            .foregroundStyle(Theme.cream)
                        Text(result.message)
                            .bodyText(15)
                            .foregroundStyle(Theme.cream.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .fill(Theme.safetyRed)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .strokeBorder(Theme.cream.opacity(0.25), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .offset(y: -10)))
            }
        }
    }
}

// MARK: - Messages

private struct MessageRow: View {
    let message: ChatMessage
    let onOpen: (Remedy) -> Void

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 12) {
            HStack {
                if message.role == .user { Spacer(minLength: 40) }
                Text(message.text)
                    .bodyText(15)
                    .foregroundStyle(message.role == .user ? Theme.onCream : Theme.cream.opacity(0.92))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                            .fill(message.isSafetyEscalation ? Theme.safetyRed.opacity(0.12) : (message.role == .user ? Theme.cream : Theme.surface))
                    }
                    .overlay {
                        if message.role == .grounded {
                            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                                .strokeBorder(
                                    message.isSafetyEscalation ? Theme.safetyRed.opacity(0.65) : (message.isError ? Theme.cream.opacity(0.22) : Theme.hairline),
                                    lineWidth: message.isSafetyEscalation ? 1.5 : 1
                                )
                        }
                    }
                if message.role == .grounded { Spacer(minLength: 40) }
            }

            ForEach(message.suggestions) { remedy in
                RemedySuggestionCard(remedy: remedy) { onOpen(remedy) }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .transition(.opacity.combined(with: .offset(y: 8)))
    }
}

/// A remedy suggestion inside the thread — distinct from the message bubble.
struct RemedySuggestionCard: View {
    let remedy: Remedy
    let onOpen: () -> Void

    @Environment(RemedyLibrary.self) private var library

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(remedy.category)
                            .sectionEyebrow(12)
                        Text(remedy.name)
                            .screenHeadline(24)
                            .foregroundStyle(Theme.cream)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    UIChromeIcon(systemName: "arrow.up.right", size: 12, color: Theme.cream.opacity(0.6))
                }

                detailLine(icon: "mortar.and.pestle", text: remedy.prepType)
                detailLine(icon: "clock", glyph: .clock, text: remedy.dosageFrequency)

                HStack(alignment: .center, spacing: 8) {
                    // Inside the card's own button label, so the pill cannot take the tap —
                    // opening the remedy wins here, and its detail screen has a live pill.
                    EvidenceTierBadge(tier: remedy.evidenceTier, explains: false)
                    Spacer()
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.categoryColor(library.colorHex(forCategory: remedy.category)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.cream.opacity(0.12), lineWidth: 1)
            }
            .ambientElevation(.raised)
        }
        .buttonStyle(SoftPressStyle(scale: 0.985))
    }

    private func detailLine(icon: String, glyph: LineGlyph? = nil, text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Group {
                if let glyph {
                    LineIcon(glyph: glyph, size: 14, tint: Theme.cream.opacity(0.8))
                } else {
                    UIChromeIcon(systemName: icon, size: 12, color: Theme.cream.opacity(0.65))
                }
            }
            .frame(width: 14)
            .padding(.top, 2)
            Text(text)
                .captionText(13, color: Theme.cream.opacity(0.88))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ThinkingBubble: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBar(width: 190)
            SkeletonBar(width: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
    }
}

// MARK: - Composer

private struct ChatComposer: View {
    @Bindable var chat: ChatModel
    @FocusState.Binding var isFocused: Bool

    private var canSend: Bool {
        !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chat.isThinking
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask about a symptom", text: $chat.draft, axis: .vertical)
                .bodyText(15)
                .foregroundStyle(Theme.cream)
                .tint(Theme.cream)
                .lineLimit(1...4)
                .focused($isFocused)
                .submitLabel(.send)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background {
                    Capsule(style: .continuous)
                        .fill(Theme.surface)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.cream.opacity(isFocused ? 0.28 : 0.12), lineWidth: 1)
                }
                // Taps anywhere on the capsule land in the field, not just on the glyphs.
                .contentShape(.capsule)
                .onTapGesture { isFocused = true }
                .animation(.easeOut(duration: 0.2), value: isFocused)

            Button {
                guard canSend else { return }
                Task { await chat.send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onCream)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.cream))
            }
            .buttonStyle(SoftPressStyle(scale: 0.92))
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.35)
            .animation(.easeOut(duration: 0.18), value: canSend)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .background {
            // Keeps the thread readable as it scrolls under the composer.
            Rectangle()
                .fill(Theme.background.opacity(0.92))
                .blur(radius: 12)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Sheet

/// Remedy detail presented from the chat thread.
struct RemedyDetailSheet: View {
    let remedy: Remedy

    var body: some View {
        NavigationStack {
            RemedyDetailView(remedy: remedy, onFollowUp: nil)
        }
    }
}
