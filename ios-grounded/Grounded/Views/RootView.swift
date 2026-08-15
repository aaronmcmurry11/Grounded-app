import SwiftUI
import UIKit

nonisolated enum AppTab: String, CaseIterable, Hashable {
    case chat, apothecary, scan, account

    var title: String {
        switch self {
        case .chat: "Chat"
        case .apothecary: "Apothecary"
        case .scan: "Scan"
        case .account: "Account"
        }
    }

    /// Tier C — drawn, not an SF Symbol, so the nav set carries the same stroke weight and
    /// rounded terminals as the prep-type and section glyphs.
    var glyph: LineGlyph {
        switch self {
        case .chat: .chat
        case .apothecary: .apothecary
        case .scan: .scan
        case .account: .account
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if appModel.hasCompletedOnboarding {
                MainShell()
            } else {
                OnboardingView()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: appModel.hasCompletedOnboarding)
    }
}

struct MainShell: View {
    @State private var selectedTab: AppTab = .chat
    @State private var chatModel: ChatModel?
    @Environment(RemedyLibrary.self) private var library

    var body: some View {
        ZStack(alignment: .bottom) {
            AtmosphericBackground()

            Group {
                switch selectedTab {
                case .chat:
                    if let chatModel {
                        // Chat is the one tab that clears the bar itself: its composer is
                        // pinned to the bottom and has to track the keyboard, so it owns
                        // that measurement rather than inheriting a fixed inset.
                        ChatView(chat: chatModel)
                    }
                case .apothecary:
                    ApothecaryView(onFollowUp: handleFollowUp)
                        .clearsFloatingTabBar()
                case .scan:
                    ScannerView()
                        .clearsFloatingTabBar()
                case .account:
                    AccountView(onOpenRemedy: { _ in selectedTab = .apothecary })
                        .clearsFloatingTabBar()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            GroundedTabBar(selected: $selectedTab)
                // The bar must never ride up with the keyboard — otherwise it lands
                // on top of the chat composer and swallows taps meant for the field.
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .task {
            if chatModel == nil {
                chatModel = ChatModel(library: library)
            }
        }
    }

    private func handleFollowUp(_ remedy: Remedy) {
        chatModel?.prefill(followUpFor: remedy)
        selectedTab = .chat
    }
}

private struct GroundedTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    guard tab != selected else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    selected = tab
                } label: {
                    VStack(spacing: 5) {
                        LineIcon(
                            glyph: tab.glyph,
                            size: 22,
                            tint: selected == tab ? Theme.cream : Theme.cream.opacity(0.42),
                            isEmphasized: selected == tab
                        )
                        // The scale's UI-label role, held at 11pt: four labels must fit
                        // across one capsule, so the 15-16pt band cannot apply here.
                        Text(tab.title)
                            .uiLabel(11, weight: selected == tab ? 600 : 400)
                    }
                    .foregroundStyle(selected == tab ? Theme.cream : Theme.cream.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if selected == tab {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Theme.cream.opacity(0.08))
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(SoftPressStyle(scale: 0.94))
                .accessibilityIdentifier("tab.\(tab.rawValue)")
            }
        }
        .padding(6)
        .background {
            Capsule(style: .continuous)
                .fill(Theme.surface.opacity(0.96))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
        }
        .ambientElevation(.floating)
        .padding(.horizontal, 18)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selected)
    }
}
