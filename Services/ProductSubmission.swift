import Foundation

nonisolated struct ProductGradeResult {
    let grade: String
    let summary: String
    /// One line per flagged ingredient (or a single "nothing flagged" line), plain enough
    /// to render directly as the result screen's ingredient list.
    let notedIngredients: [String]
}

/// Deterministic, keyword-based grading against Grounded's *own* criteria — never sourced
/// from or presented as a third-party rating (EWG, Yuka, or similar). This grades only what
/// the ingredient-list text returned by Open Food Facts/Open Beauty Facts can actually show;
/// it cannot detect things a label doesn't state (e.g. real pesticide-residue levels), so a
/// category that can't be verified from label text alone is worded as a transparency note,
/// not a hazard claim — consistent with the app's educational-only framing.
///
/// This is a first-pass rubric (v0.1), not a validated grading system. See
/// `claude/barcode-grading-rubric.md` in the project docs for the full sourcing per category
/// and what's still needed (a dedicated methodology review, matching the same bar the
/// red-flag triage rules went through) before this should be trusted for a real launch.
enum ProductGrading {

    // Deliberately the specific example categories the project brief itself named (seed
    // oils, artificial dyes, glyphosate-adjacent flags, artificial preservatives) rather
    // than an invented list — keeps the rubric's scope traceable back to a real source.
    private static let seedOils = [
        "soybean oil", "canola oil", "rapeseed oil", "corn oil", "cottonseed oil",
        "sunflower oil", "safflower oil", "grapeseed oil", "rice bran oil", "vegetable oil",
    ]
    private static let artificialDyes = [
        "red 40", "allura red", "yellow 5", "tartrazine", "yellow 6", "sunset yellow",
        "blue 1", "brilliant blue", "blue 2", "indigotine", "green 3",
        "artificial color", "artificial colour",
    ]
    private static let artificialPreservatives = [
        "bha", "bht", "tbhq", "sodium benzoate", "potassium sorbate",
        "sodium nitrite", "sodium nitrate", "potassium nitrite", "potassium nitrate",
    ]
    // Ingredient text alone can never confirm actual pesticide residue — this only flags a
    // published, real agricultural practice (pre-harvest desiccation) on specific
    // conventional (non-organic) crops, worded as a transparency note rather than a finding.
    private static let desiccationRiskCrops = ["wheat", "oats", "oat", "barley"]

    static func grade(ingredientsText: String, isOrganic: Bool) -> ProductGradeResult {
        let text = ingredientsText.lowercased()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ProductGradeResult(
                grade: "—",
                summary: "This product's label didn't include an ingredient list we could grade.",
                notedIngredients: ["No ingredient text was available from the product database."]
            )
        }

        var notes: [String] = []
        var deductions = 0

        if let hit = firstMatch(seedOils, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — an industrial seed oil; traditional-health approaches often favor more stable, less-processed fats instead.")
        }
        if let hit = firstMatch(artificialDyes, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — a synthetic dye. Some of these carry an EU hyperactivity warning label; the EU permits them with that condition rather than banning them.")
        }
        if let hit = firstMatch(artificialPreservatives, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — a synthetic preservative, permitted at regulated levels but flagged by some traditional-health sources.")
        }
        if !isOrganic, let hit = firstMatch(desiccationRiskCrops, in: text) {
            // Transparency note only — deliberately does not add a deduction, since this
            // isn't a confirmed finding about this specific product.
            notes.append("\(hit.capitalized) (not labeled organic) — this app can't test for pesticide residue directly. Conventional \(hit) is sometimes pre-harvest desiccated with glyphosate in some growing regions; noted for transparency, not as a confirmed finding about this product.")
        }

        if notes.isEmpty {
            notes.append("No ingredients matched Grounded's current flagged-ingredient list.")
        }

        return ProductGradeResult(
            grade: letterGrade(forDeductions: deductions),
            summary: summary(forDeductions: deductions),
            notedIngredients: notes
        )
    }

    private static func firstMatch(_ keywords: [String], in text: String) -> String? {
        keywords.first { text.contains($0) }
    }

    // Caps at "D": only three categories currently carry a deduction, so "F" isn't reachable
    // yet with this rubric's current scope — headroom for future categories, not a bug.
    private static func letterGrade(forDeductions deductions: Int) -> String {
        switch deductions {
        case 0: return "A"
        case 1: return "B"
        case 2: return "C"
        default: return "D"
        }
    }

    private static func summary(forDeductions deductions: Int) -> String {
        switch deductions {
        case 0: return "No ingredients flagged against Grounded's current criteria."
        case 1: return "One ingredient flagged against Grounded's criteria — see below."
        default: return "\(deductions) ingredients flagged against Grounded's criteria — see below."
        }
    }
}
