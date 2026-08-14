import Foundation

/// Loads the curated, cited remedy seed data bundled with the app.
@Observable
final class RemedyLibrary {
    private(set) var categories: [RemedyCategory] = []
    private(set) var remedies: [Remedy] = []
    private(set) var loadFailed = false
    /// Long-form tier definitions straight from the seed file, keyed by tier raw value.
    private(set) var tierDefinitions: [String: String] = [:]
    /// Catalog position per remedy id. The seed file's array order *is* the catalog order,
    /// so numbers stay stable as long as entries are appended rather than inserted.
    private(set) var catalogNumbers: [String: Int] = [:]

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "remedies", withExtension: "json") else {
            loadFailed = true
            print("[RemedyLibrary] remedies.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(RemedyLibraryFile.self, from: data)
            categories = file.categories
            remedies = file.remedies
            tierDefinitions = file.evidenceTierDefinitions ?? [:]
            catalogNumbers = Dictionary(
                uniqueKeysWithValues: file.remedies.enumerated().map { ($0.element.id, $0.offset + 1) }
            )
        } catch {
            loadFailed = true
            print("[RemedyLibrary] could not decode remedy library")
        }
    }

    func colorHex(forCategory name: String) -> String? {
        categories.first { $0.name == name }?.colorHex
    }

    func remedies(inCategory name: String) -> [Remedy] {
        remedies.filter { $0.category == name }
    }

    func remedy(id: String) -> Remedy? {
        remedies.first { $0.id == id }
    }

    // MARK: Catalog

    /// Zero-padded catalog reference, e.g. "No. 04". Falls back to the plain name-less form
    /// rather than a wrong number if an id somehow isn't in the catalog.
    func formattedCatalogNumber(for remedy: Remedy) -> String {
        guard let number = catalogNumbers[remedy.id] else { return "No. \u{2014}" }
        return String(format: "No. %02d", number)
    }

    /// The hand-picked entry point for a new user. Chosen for breadth and low risk: one from
    /// each shelf plus a fifth, all either conflict-free or clearly caveated, and none
    /// requiring a commercial product to try. Resolved by id so a data edit drops the entry
    /// instead of silently shifting the list.
    private static let starterIDs: [String] = [
        "saltwater-gargle-sore-throat",
        "honey-occasional-cough",
        "ginger-tea-nausea",
        "chamomile-tea-presleep-relaxation",
        "aloe-vera-minor-burns",
    ]

    var starterRemedies: [Remedy] {
        Self.starterIDs.compactMap { remedy(id: $0) }
    }

    // MARK: Search

    /// Words that carry no signal in a library this small — every entry is a remedy, and
    /// half the ailments already say "occasional".
    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "occasional", "occasionally", "help", "helps", "helping",
        "remedy", "remedies", "something", "trouble", "problem", "problems", "issue", "from",
        "that", "this", "have", "having", "about", "best", "good", "what", "how", "use", "used",
        "treat", "treatment", "cure", "relief", "relieve", "can't", "cant", "feeling", "feel",
    ]

    /// Everyday phrasing mapped onto the vocabulary the seed data actually uses. People
    /// search for how a symptom feels ("stuffy nose"), not how a monograph names it
    /// ("nasal or sinus congestion").
    private static let synonyms: [String: [String]] = [
        "sleeping": ["sleep"],
        "asleep": ["sleep"],
        "insomnia": ["sleep"],
        "restless": ["sleep", "relax"],
        "awake": ["sleep"],
        "tired": ["sleep"],
        "stuffy": ["congestion"],
        "blocked": ["congestion"],
        "congested": ["congestion"],
        "nose": ["nasal"],
        "sinuses": ["sinus"],
        "queasy": ["nausea"],
        "sick": ["nausea", "cold"],
        "vomiting": ["nausea"],
        "stomach": ["digestive", "nausea"],
        "tummy": ["digestive"],
        "gas": ["gas", "bloating"],
        "gassy": ["gas", "bloating"],
        "bloated": ["bloating"],
        "bloat": ["bloating"],
        "indigestion": ["heartburn", "indigestion"],
        "reflux": ["heartburn"],
        "acid": ["heartburn"],
        "itching": ["itchy"],
        "itch": ["itchy"],
        "rash": ["skin", "irritated"],
        "eczema": ["skin", "itchy"],
        "sunburn": ["burn"],
        "burns": ["burn"],
        "burnt": ["burn"],
        "cut": ["wound"],
        "cuts": ["wound"],
        "scrape": ["wound"],
        "wounds": ["wound"],
        "coughing": ["cough"],
        "flu": ["flu", "cold"],
        "immunity": ["immune"],
        "throats": ["throat"],
    ]

    private static func terms(in query: String) -> [String] {
        query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopwords.contains($0) }
    }

    /// True when this term (or any everyday synonym of it) appears anywhere in the entry.
    private static func matches(term: String, in haystack: String) -> Bool {
        if haystack.contains(term) { return true }
        return (synonyms[term] ?? []).contains { haystack.contains($0) }
    }

    /// Apothecary search across name, ailment, ingredients, description, category and prep.
    ///
    /// Two passes: entries matching *every* term first, and only if that finds nothing does
    /// it fall back to entries matching any term, ranked by how many. A strict-only search
    /// drops "sore throat honey"; a loose-only search answers "sore throat" with half the
    /// library. This gets precision when precision exists and recall when it doesn't.
    func search(_ query: String) -> [Remedy] {
        let terms = Self.terms(in: query)
        guard !terms.isEmpty else { return [] }

        let scored: [(remedy: Remedy, score: Int)] = remedies.map { remedy in
            let haystack = remedy.searchHaystack
            let score = terms.count { Self.matches(term: $0, in: haystack) }
            return (remedy, score)
        }

        let complete = scored.filter { $0.score == terms.count }
        if !complete.isEmpty { return complete.map(\.remedy) }

        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map(\.remedy)
    }

    /// Starter searches for the empty state, drawn from ailment wording in the seed data and
    /// then *verified against the index* — a chip that returns nothing never renders, so
    /// these can't rot as entries change.
    private static let searchSuggestions = [
        "Sore throat", "Trouble sleeping", "Bloating", "Nausea", "Itchy skin",
    ]

    var suggestedSearches: [String] {
        Self.searchSuggestions.filter { !search($0).isEmpty }
    }

    // MARK: Sourcing / trust

    /// Falls back to the short model-level explanation if the seed file has no entry.
    func definition(for tier: EvidenceTier) -> String {
        tierDefinitions[tier.rawValue] ?? tier.explanation
    }

    func count(for tier: EvidenceTier) -> Int {
        remedies.count { $0.evidenceTier == tier }
    }

    /// Total citations across the library. Counted rather than stated, so the trust screen
    /// can never drift out of sync with the seed data.
    var citationCount: Int {
        remedies.reduce(0) { $0 + $1.sources.count }
    }

    var fundingCheckedCount: Int {
        remedies.count { $0.fundingConflictChecked == true }
    }

    var safetyFlaggedCount: Int {
        remedies.count { $0.safetyFlag != nil }
    }

    var annotatedCount: Int {
        remedies.count { $0.evidenceNote?.isEmpty == false }
    }

    /// Lightweight local match used by the v1 chat shell. No retrieval / grounding yet.
    func matches(for query: String, limit: Int = 2) -> [Remedy] {
        let terms = query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        guard !terms.isEmpty else { return [] }

        let scored: [(Remedy, Int)] = remedies.map { remedy in
            let haystack = [remedy.name, remedy.ailment, remedy.shortDescription, remedy.category, remedy.prepType]
                .joined(separator: " ")
                .lowercased()
            let score = terms.reduce(0) { partial, term in
                partial + (haystack.contains(term) ? 1 : 0)
            }
            return (remedy, score)
        }
        return scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}
