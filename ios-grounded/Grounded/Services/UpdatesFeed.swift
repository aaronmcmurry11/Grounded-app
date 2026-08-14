import Foundation
import Observation

/// The Updates inbox feed.
///
/// v1 ships a fixed sample set written in the same voice as the sourcing documentation —
/// what changed, and what evidence moved it. It is deliberately shaped like a real feed
/// (async `load()`, a loading phase, a failure path) so that swapping the static array for a
/// fetch later is a change to one method and nothing else.
@Observable
final class UpdatesFeed {
    private(set) var entries: [AppUpdate] = []
    private(set) var isLoading = true
    private(set) var loadFailed = false

    /// Idempotent: the inbox is opened repeatedly and `.task` fires on every presentation.
    func loadIfNeeded() async {
        guard entries.isEmpty, !loadFailed else {
            isLoading = false
            return
        }
        entries = Self.sampleEntries.sorted { $0.date > $1.date }
        isLoading = false
    }

    /// Entries the user's channel preferences allow through.
    func entries(allowing isEnabled: (UpdateChannel) -> Bool) -> [AppUpdate] {
        entries.filter { isEnabled($0.channel) }
    }

    /// Unread means "arrived since you last opened the inbox". A user who has never opened
    /// it sees everything as unread, which is the correct first-run state.
    func unreadCount(since lastOpened: Date?, allowing isEnabled: (UpdateChannel) -> Bool) -> Int {
        let visible = entries(allowing: isEnabled)
        guard let lastOpened else { return visible.count }
        return visible.filter { $0.date > lastOpened }.count
    }

    // MARK: Sample content

    private static let sampleEntries: [AppUpdate] = [
        AppUpdate(
            id: "elderberry-tier-downgrade",
            channel: .savedRemedies,
            title: "Elderberry's evidence tier was updated to Traditional Use",
            body: "Elderberry Syrup previously sat at Clinical tier on the strength of two positive trials. Both were funded by manufacturers of the standardised extract being tested, and a later independent trial found no meaningful effect on cold duration. The entry now sits at Traditional use, and the funding picture is written into its sourcing transparency note.",
            daysAgo: 3,
            remedyID: "elderberry-syrup-cold-flu"
        ),
        AppUpdate(
            id: "peppermint-caution-added",
            channel: .savedRemedies,
            title: "A form caution was added to enteric-coated peppermint oil",
            body: "Non-enteric-coated peppermint oil can relax the lower oesophageal sphincter and worsen reflux — the coating is what carries the oil past the stomach. The entry now carries that distinction at shelf level rather than only in its contraindications.",
            daysAgo: 9,
            remedyID: "peppermint-oil-ibs-bloating"
        ),
        AppUpdate(
            id: "honey-cough-funding-check",
            channel: .savedRemedies,
            title: "Honey for occasional cough passed a funding check",
            body: "The paediatric cough trials behind this entry were re-checked for sponsor involvement. All three are independently funded, and the entry keeps its Clinical tier. Its infant-botulism caution is unchanged: never for children under one year.",
            daysAgo: 16,
            remedyID: "honey-occasional-cough"
        ),
        AppUpdate(
            id: "new-slippery-elm",
            channel: .newInSavedCategories,
            title: "Slippery Elm was added to Digestive",
            body: "Added at Traditional use. The demulcent action is well documented in herbal monographs but has no controlled human trials behind it, and the entry says so. It carries an absorption note: slippery elm can slow the uptake of medication taken at the same time.",
            daysAgo: 6,
            remedyID: "slippery-elm-digestive-soothing",
            categoryName: "Digestive"
        ),
        AppUpdate(
            id: "new-tart-cherry",
            channel: .newInSavedCategories,
            title: "Tart Cherry Juice was added to Sleep",
            body: "Added at Clinical tier on two small crossover trials measuring sleep duration. Both are small and short, which is recorded on the entry — a tier describes the kind of evidence behind a remedy, not how strong that evidence is.",
            daysAgo: 21,
            remedyID: "tart-cherry-juice-sleep",
            categoryName: "Sleep"
        ),
        AppUpdate(
            id: "app-catalog-numbers",
            channel: .appNews,
            title: "Catalog numbers and broader search",
            body: "Every entry now carries a catalog number, and search reads ailments and ingredients rather than names alone — so \"trouble sleeping\" and \"chamomile\" both find the same shelf.",
            daysAgo: 1
        ),
        AppUpdate(
            id: "app-sourcing-transparency",
            channel: .appNews,
            title: "Sourcing transparency moved behind a label",
            body: "Funding notes used to sit inline above the preparation steps. They now live in a labelled disclosure inside the evidence section, collapsed by default, with the check status readable without expanding it.",
            daysAgo: 12
        ),
    ]
}
