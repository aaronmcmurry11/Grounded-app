import Foundation

/// Evidence tier shown on remedy cards. A third tier ("Reviewed by [team] herbalist")
/// exists in the design spec with no content behind it yet — the type supports it so the
/// badge component can render it later without changes.
nonisolated enum EvidenceTier: String, Codable, Hashable, CaseIterable {
    case traditionalUse = "Traditional use"
    case clinical = "Clinical tier"
    case herbalistReviewed = "Reviewed by [team] herbalist"

    var label: String { rawValue }

    /// Short, educational explanation of what the tier means.
    var explanation: String {
        switch self {
        case .traditionalUse:
            return "Documented traditional or folk use, typically backed by a government or regulatory herbal monograph rather than a dedicated clinical trial."
        case .clinical:
            return "At least one peer-reviewed human study or a regulatory monograph citing clinical evidence. This does not guarantee strong or conclusive evidence."
        case .herbalistReviewed:
            return "Reviewed by a practitioner on the Grounded team. Not currently populated."
        }
    }
}

/// A quiet "read this one closely" signal shown at shelf level, before the user taps in.
///
/// Deliberately narrower than "has a `safetyFlag`" — 11 of the 20 entries carry a flag, and
/// badging over half the shelf would train people to ignore the mark. This covers only the
/// two cases where the remedy is genuinely safe *in the wrong hands or the wrong form*, and
/// so a reader who skims the name alone could get it wrong. Interaction and
/// scope-of-use flags (sedatives, absorption, deep wounds) stay inside Remedy Detail, where
/// there's room to state them properly.
nonisolated enum CautionSignal: Hashable {
    /// Safe only in one specific preparation.
    case form(String)
    /// Not safe for a specific group of people.
    case population(String)

    var reason: String {
        switch self {
        case let .form(reason), let .population(reason): reason
        }
    }

    /// Maps the seed data's `safetyFlag` vocabulary. Flags absent from this table are real
    /// safety information but not *form-or-population* traps, so they don't earn a badge.
    static func forFlag(_ flag: String) -> CautionSignal? {
        switch flag {
        case "infant-botulism-risk":
            .population("Never for infants under one year")
        case "not-for-young-children":
            .population("Not for young children")
        case "raw-berries-toxic":
            .form("Must be fully cooked — raw berries are toxic")
        case "cardiac-bp-risk-if-non-dgl":
            .form("Only the DGL form is safe for repeated use")
        case "never-apply-undiluted-essential-oil":
            .form("Essential oil must be diluted before skin contact")
        default:
            nil
        }
    }
}

nonisolated struct RemedyCategory: Codable, Hashable, Identifiable {
    let name: String
    let colorHex: String

    var id: String { name }
}

nonisolated struct Remedy: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let category: String
    let shortDescription: String
    let ailment: String
    let prepType: String
    let ingredients: [String]
    let directions: [String]
    let dosageFrequency: String
    let contraindications: [String]
    let sources: [String]
    let evidenceTier: EvidenceTier
    /// Real nuance behind the evidence claim — surfaced as a secondary caption when present.
    let evidenceNote: String?
    /// When non-nil, the contraindications section gets safety-red emphasis.
    let safetyFlag: String?
    /// True when the funding behind this entry's cited studies was checked and recorded.
    /// Absent on entries that rest on monographs rather than sponsored trials.
    let fundingConflictChecked: Bool?

    /// Shelf-level caution mark, derived from `safetyFlag`. Nil for most entries by design —
    /// see `CautionSignal`.
    var cautionSignal: CautionSignal? {
        guard let safetyFlag else { return nil }
        return CautionSignal.forFlag(safetyFlag)
    }

    /// Everything the search index reads. Kept on the model so the fields searched can't
    /// drift apart from the fields displayed.
    var searchHaystack: String {
        ([name, ailment, shortDescription, category, prepType] + ingredients)
            .joined(separator: " ")
            .lowercased()
    }
}

nonisolated struct RemedyLibraryFile: Codable {
    let categories: [RemedyCategory]
    let remedies: [Remedy]
    /// The long-form tier definitions authored alongside the seed data. Preferred over
    /// `EvidenceTier.explanation` wherever there's room for the fuller wording.
    let evidenceTierDefinitions: [String: String]?
}
