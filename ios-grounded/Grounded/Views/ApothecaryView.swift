import SwiftUI

/// Browsable remedy library, grouped into named category shelves.
struct ApothecaryView: View {
    let onFollowUp: (Remedy) -> Void

    @Environment(RemedyLibrary.self) private var library
    @Environment(AppModel.self) private var appModel
    @State private var query: String = ""
    @State private var expanded: Set<String> = ["Respiratory"]
    @State private var path: [Remedy] = []

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var searchResults: [Remedy] {
        library.search(query)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    VStack(alignment: .leading, spacing: 12) {
                        searchField
                        if !isSearching {
                            suggestionChips
                        }
                    }

                    if isSearching {
                        VStack(spacing: 12) {
                            if searchResults.isEmpty {
                                emptyResults
                            } else {
                                ForEach(searchResults) { remedy in
                                    RemedyListRow(remedy: remedy) { path.append(remedy) }
                                }
                            }
                        }
                    } else {
                        // Omitted entirely rather than hidden: an `if` inside the stack drops
                        // its spacing with it, so a dismissed strip leaves search sitting
                        // directly above the shelves with no empty band.
                        if !appModel.hasDismissedStartHere {
                            StartHereCard(
                                remedies: library.starterRemedies,
                                onSelect: { path.append($0) },
                                onDismiss: dismissStartHere
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                        }

                        VStack(spacing: 14) {
                            ForEach(library.categories) { category in
                                CategoryShelf(
                                    category: category,
                                    remedies: library.remedies(inCategory: category.name),
                                    isExpanded: expanded.contains(category.name),
                                    onToggle: { toggle(category.name) },
                                    onSelect: { path.append($0) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .background(Color.clear)
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(for: Remedy.self) { remedy in
                RemedyDetailView(remedy: remedy, onFollowUp: onFollowUp)
            }
        }
        .tint(Theme.cream)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The Apothecary — Volume I")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)
            // Shelf count is read from the data rather than written as "four", so the line
            // can't go stale the day a fifth shelf is added.
            Text("\(library.remedies.count) sourced entries across \(library.categories.count) shelves")
                .captionText(12)
        }
        .padding(.top, 14)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            // Small functional icon: full-opacity cream, per the tier color rules.
            LineIcon(glyph: .search, size: 18)
            TextField("Search by remedy, concern, or ingredient", text: $query)
                .bodyText(15)
                .foregroundStyle(Theme.cream)
                .tint(Theme.cream)
                .autocorrectionDisabled()
            if isSearching {
                Button {
                    query = ""
                } label: {
                    // Tier D: conventional clear affordance, weight-harmonized only.
                    UIChromeIcon(systemName: "xmark.circle.fill", size: 15, color: Theme.creamFaint)
                }
                .buttonStyle(SoftPressStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            Capsule(style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }

    /// Empty-field prompts. Every chip is verified against the index before it renders, so
    /// tapping one can never land on "nothing on the shelf for that".
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(library.suggestedSearches, id: \.self) { suggestion in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            query = suggestion
                        }
                    } label: {
                        Text(suggestion)
                            .uiLabel(13)
                            .foregroundStyle(Theme.cream.opacity(0.88))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(Theme.cream.opacity(0.06))
                            }
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(Theme.cream.opacity(0.16), lineWidth: 1)
                            }
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel("Search for \(suggestion)")
                }
            }
        }
        // Margins on the ScrollView, not padding on the row — padding would leave a
        // permanent dead strip at both edges once the chips scroll.
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollClipDisabled()
    }

    private var emptyResults: some View {
        VStack(spacing: 10) {
            BotanicalSprig(lineWidth: 1)
                .frame(width: 54, height: 74)
                .opacity(0.5)
            Text("Nothing on the shelf for that")
                .screenHeadline(24)
                .foregroundStyle(Theme.cream)
            Text("Try a broader term — cough, nausea, sleep, or skin.")
                .captionText(13)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func dismissStartHere() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            appModel.hasDismissedStartHere = true
        }
    }

    private func toggle(_ name: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            if expanded.contains(name) {
                expanded.remove(name)
            } else {
                expanded.insert(name)
            }
        }
    }
}

// MARK: - Start here

/// The new-user entry point, sitting above the shelves.
///
/// Inverted to cream-on-dark-text — the same pairing as a primary CTA and an expanded shelf
/// header — so it reads as the one lit thing on the screen without needing a fifth colour or
/// competing with the four category hues below it.
private struct StartHereCard: View {
    let remedies: [Remedy]
    let onSelect: (Remedy) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start here")
                        .sectionEyebrow(12, color: Theme.onCream.opacity(0.55))
                    Text("Five remedies every home apothecary starts with")
                        .shelfTitle(24)
                        .foregroundStyle(Theme.onCream)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Where the sprig used to sit. Two marks in one corner would fight, and the
                // dismiss control has to win that corner — it's the only one that does
                // anything.
                Button(action: onDismiss) {
                    UIChromeIcon(systemName: "xmark", size: 12, color: Theme.onCream.opacity(0.55))
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(Theme.onCream.opacity(0.07))
                        }
                        .contentShape(.circle)
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel("Hide Start here")
                .accessibilityHint("Removes this section from the Apothecary")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(remedies) { remedy in
                        StarterCard(remedy: remedy) { onSelect(remedy) }
                    }
                }
            }
            // Margin on the scroll content, not padding on the row: the first and last card
            // line up with the header's 20pt margin, and cards still travel to both edges
            // instead of parking behind a permanent inset strip.
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Theme.cream)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .ambientElevation(.raised)
    }
}

/// A compact starter card for the horizontal strip, drawn in the inverse palette.
///
/// No prep-type glyph at this width: the card is carrying a catalog number, a category tag,
/// the name and an evidence pill, and the glyph was the one element that repeated information
/// available in full one tap away.
private struct StarterCard: View {
    let remedy: Remedy
    let onSelect: () -> Void

    @Environment(RemedyLibrary.self) private var library

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(library.formattedCatalogNumber(for: remedy))
                        .catalogNumber(11, color: Theme.onCream.opacity(0.5))
                    if let signal = remedy.cautionSignal {
                        CautionBadge(signal: signal, tint: Theme.onCream, size: 12)
                    }
                }

                Text(remedy.category)
                    .sectionEyebrow(11, color: Theme.onCream.opacity(0.45))
                    .padding(.top, 3)
                    .lineLimit(1)

                Text(remedy.name)
                    .listItemTitle(16)
                    .foregroundStyle(Theme.onCream)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.top, 8)

                // Pins the pill to the card's bottom edge so a one-line and a two-line name
                // still line their pills up across the strip.
                Spacer(minLength: 10)

                EvidenceTierBadge(
                    tier: remedy.evidenceTier,
                    isCompact: true,
                    onLightSurface: true,
                    // The card owns the tap. A button nested in another button's label never
                    // receives it, and at this size there's no room for the sibling-pill
                    // arrangement the full shelf rows use.
                    explains: false
                )
            }
            .padding(14)
            .frame(width: 152, height: 148, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.onCream.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.onCream.opacity(0.14), lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [
            library.formattedCatalogNumber(for: remedy),
            remedy.name,
            remedy.category,
            remedy.evidenceTier.label,
        ]
        if let signal = remedy.cautionSignal {
            parts.append("Read closely: \(signal.reason)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Shelf

private struct CategoryShelf: View {
    let category: RemedyCategory
    let remedies: [Remedy]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: (Remedy) -> Void

    /// Expanded shelves invert to the cream/near-black pairing used by primary CTAs, so the
    /// category hue moves down onto the cards it contains and only one shelf reads as open.
    private var headerBackground: Color {
        isExpanded ? Theme.cream : Theme.categoryColor(category.colorHex)
    }

    private var headerForeground: Color {
        isExpanded ? Theme.onCream : Theme.cream
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.name)
                            .shelfTitle(28)
                            .foregroundStyle(headerForeground)
                        Text("\(remedies.count) remedies")
                            .captionText(12, color: headerForeground.opacity(0.7))
                    }
                    Spacer()
                    BotanicalSprig(lineWidth: 1, tint: headerForeground)
                        .frame(width: 34, height: 50)
                        .opacity(0.55)
                    UIChromeIcon(systemName: "chevron.down", size: 13, color: headerForeground.opacity(0.75))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.leading, 6)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                        .fill(headerBackground)
                }
                .contentShape(.rect)
            }
            .buttonStyle(SoftPressStyle(scale: 0.99))

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(Array(remedies.enumerated()), id: \.element.id) { index, remedy in
                        RemedyListRow(remedy: remedy) { onSelect(remedy) }
                            .transition(.opacity.combined(with: .offset(y: 10)))
                            .animation(
                                .spring(response: 0.42, dampingFraction: 0.88).delay(Double(index) * 0.04),
                                value: isExpanded
                            )
                    }
                }
                .padding(.top, 10)
            }
        }
        .clipped()
    }
}

/// Shelf card: prep glyph, catalog number, remedy name, and an evidence-tier pill, on the
/// full category hue. Description and `evidenceNote` are deliberately absent here — both
/// appear in full on Remedy Detail, and the list reads as a scannable shelf without them.
struct RemedyListRow: View {
    let remedy: Remedy
    let onSelect: () -> Void

    @Environment(RemedyLibrary.self) private var library

    var body: some View {
        // Two sibling buttons rather than a pill nested inside the row button: a button
        // inside another button's label never receives the tap, so the evidence pill can
        // only open the sourcing sheet if it lives outside the row's own hit area.
        HStack(alignment: .center, spacing: 12) {
            Button(action: onSelect) {
                HStack(alignment: .center, spacing: 12) {
                    PrepTypeIcon(prepType: remedy.prepType, size: 18, tint: Theme.cream)
                        .opacity(0.9)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(library.formattedCatalogNumber(for: remedy))
                                .catalogNumber(11, color: Theme.cream.opacity(0.55))
                            if let signal = remedy.cautionSignal {
                                CautionBadge(signal: signal, size: 12)
                            }
                        }
                        Text(remedy.name)
                            .listItemTitle(17)
                            .foregroundStyle(Theme.cream)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(SoftPressStyle(scale: 0.985))
            // The glyph and the caution mark are both decorative, so everything they signal
            // is spoken here instead.
            .accessibilityLabel(accessibilityLabel)

            EvidenceTierBadge(
                tier: remedy.evidenceTier,
                onCategoryColor: true,
                isCompact: true
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.categoryColor(library.colorHex(forCategory: remedy.category)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            library.formattedCatalogNumber(for: remedy),
            remedy.name,
            PrepKind.classify(remedy.prepType).label,
            remedy.evidenceTier.label,
        ]
        if let signal = remedy.cautionSignal {
            parts.append("Read closely: \(signal.reason)")
        }
        return parts.joined(separator: ", ")
    }
}
