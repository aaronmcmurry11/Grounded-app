import Foundation

/// Two independent badges rather than one blended verdict — see `claude/barcode-grading-v0.3-spec.md`
/// for the reasoning. `purity` is v0.1/v0.2's original axis (does this avoid the ingredients
/// Grounded flags), expanded with new categories. `nourishment` is new in v0.3: does this
/// actually look like real, ancestral, nutrient-dense food, independent of whether it also
/// avoids the flagged stuff. A product can be clean on `purity` and still land an F on
/// `nourishment` if it has nothing going for it nutritionally — that's intentional, not a bug.
nonisolated struct ProductGradeResult {
    let purityGrade: String
    let puritySummary: String
    /// One line per flagged/noted item (or a single "nothing flagged" line).
    let purityNotes: [String]

    let nourishmentGrade: String
    let nourishmentSummary: String
    let nourishmentNotes: [String]
}

/// Deterministic, keyword-based grading against Grounded's *own* criteria — never sourced
/// from or presented as a third-party rating (EWG, Yuka, or similar). This grades only what
/// the ingredient-list text, product name, and label tags returned by Open Food Facts/Open
/// Beauty Facts can actually show; it cannot detect things a label doesn't state (e.g. real
/// pesticide-residue levels, actual farming conditions, actual nutrient density), so a
/// category that can't be verified from that data alone is worded as a transparency note or
/// left out entirely, not asserted as a hazard or a health claim — consistent with the app's
/// educational-only framing and the "never diagnostic or prescriptive" guardrail.
///
/// v0.3: split into two badges (`purity` + `nourishment`, see `ProductGradeResult` above),
/// added refined flour, processed protein/starch isolates, and an ultra-processed marker to
/// the purity axis, added a conventional-meat/dairy transparency note, and added a hard
/// override for cell-cultivated/cultured meat that forces both badges to F regardless of
/// anything else. Full sourcing and the philosophy decisions behind all of this are in
/// `claude/barcode-grading-v0.3-spec.md` and `claude/barcode-grading-rubric.md` in the
/// project docs. Still not a validated grading system; see those docs for what's still needed
/// before this should be trusted for a real launch.
enum ProductGrading {

    // MARK: - Purity axis: deduction categories (v0.1/v0.2, unchanged)

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
    private static let palmOilKeywords = [
        "palm oil", "palm kernel oil", "palm fruit oil", "palm olein", "palm stearin",
    ]
    private static let unrefinedPalmOilPhrases = ["red palm oil", "unrefined palm oil", "unrefined red palm oil"]
    private static let addedSugarKeywords = [
        "sugar", "cane sugar", "corn syrup", "high fructose corn syrup", "dextrose",
        "fructose", "sucrose", "invert sugar", "brown rice syrup", "evaporated cane juice",
        "corn sweetener", "glucose syrup", "maltose",
    ]
    private static let traditionalSweeteners = ["honey", "maple syrup", "molasses", "date sugar", "coconut sugar"]
    private static let concerningEmulsifiers = [
        "carboxymethylcellulose", "carboxymethyl cellulose", "cellulose gum", "polysorbate 80",
    ]
    private static let artificialSweeteners = ["aspartame"]

    // MARK: - Purity axis: deduction categories (v0.3 — new)

    // Distinct from the desiccation-risk transparency note below, which is about a farming
    // practice, not the flour's own processing. Deliberately doesn't match bare "wheat flour"
    // (ambiguous — could be whole or refined) — only the specific qualifiers that reliably
    // signal refined/bleached flour. Sources: USDA MyPlate and Mayo Clinic on nutrient loss
    // from refining; Weston A. Price Foundation, "Replacing White Flour with Whole Grains,"
    // on the specific nutrients refining removes; 21 CFR 136 on US bleaching-agent legality
    // (potassium bromate is banned in the EU/UK since 1990, still federally legal in the US
    // pending FDA review, banned in California starting 2027).
    private static let refinedFlour = ["bleached flour", "enriched flour", "enriched wheat flour", "white flour"]

    // Protein/starch isolates as an ultra-processing marker — Monteiro et al., "Ultra-processed
    // foods: what they are and how to identify them," Public Health Nutrition, 2019, names
    // "hydrolysed protein, soy protein isolate, gluten, whey" explicitly as example marker
    // ingredients under the real NOVA classification framework. Whey protein isolate is
    // included deliberately even though whey is dairy (which this rubric otherwise treats
    // favorably) — the rule is about processing level, not animal-vs-plant origin; exempting
    // it because it's dairy-derived would undercut the rubric's own logic.
    private static let processedIsolates = [
        "soy protein isolate", "pea protein isolate", "whey protein isolate",
        "isolated wheat protein", "hydrolyzed wheat protein", "wheat protein isolate",
    ]

    // Ingredient text alone can never confirm actual pesticide residue — this only flags a
    // published, real agricultural practice (pre-harvest desiccation) on specific
    // conventional (non-organic) crops, worded as a transparency note rather than a finding.
    // "oat" (bare) was removed in v0.2 — see that changelog — it false-matched inside
    // "benzoate."
    private static let desiccationRiskCrops = ["wheat", "oats", "oat flour", "oat bran", "oat milk", "oat fiber", "barley"]

    // Terms USDA's finalized labeling rule requires directly next to a cultivated-meat
    // product's name — almost always present in `productName`, sometimes also in
    // `ingredientsText` for the specific cultivated component. Deliberately does NOT include
    // "lab-grown" — real manufacturers never use that term on labels, it's media shorthand
    // only, and matching it would risk false positives on unrelated marketing copy.
    private static let cultivatedMeatTerms = ["cell-cultivated", "cell-cultured", "cultivated"]

    // MARK: - Nourishment axis: credit signals (v0.3 — new)

    private static let wholeAnimalFoods = [
        "beef", "chicken", "pork", "turkey", "lamb", "salmon", "fish", "eggs", "egg",
        "milk", "cheese", "butter", "cream", "yogurt", "bone broth", "tallow", "lard",
        "bison", "venison",
    ]
    private static let organBonusKeywords = ["liver", "kidney", "heart", "bone broth", "organ meat", "tripe", "tongue", "marrow"]
    private static let traditionalPlantFoods = [
        "wheat", "oats", "oat", "barley", "quinoa", "lentil", "bean", "chickpea", "rice",
        "vegetable", "fruit", "carrot", "spinach", "kale", "potato", "squash", "pea",
    ]
    // US law requires raw-milk cheese sold commercially to be aged 60+ days before sale — so
    // any "raw milk cheese" found in real US commercial ingredient text is, by definition,
    // the legal aged kind, not raw fluid milk. This is deliberately NOT crediting raw fluid
    // milk itself — see the v0.3 spec doc's safety flag on raw dairy.
    private static let prepMarkers = ["fermented", "cultured", "sprouted", "soaked", "sourdough", "raw milk cheese", "raw-milk cheese"]
    private static let pastureLabels = ["grass-fed", "grass-finished", "pasture-raised", "free-range", "wild-caught", "wild caught"]

    static func grade(productName: String, ingredientsText: String, isOrganic: Bool, labelsTags: [String]) -> ProductGradeResult {
        let text = ingredientsText.lowercased()
        let name = productName.lowercased()

        // Cultivated/cultured meat override — checked before anything else, forces both
        // badges to F regardless of any other ingredient. See `cultivatedMeatTerms` above for
        // why `productName` is checked, not just `ingredientsText`.
        if cultivatedMeatTerms.contains(where: { name.contains($0) || text.contains($0) }) {
            let overrideNote = "Cell-cultivated meat — grown from animal cells in a bioreactor rather than a raised animal. Grounded's ancestral lens doesn't treat this as equivalent to traditionally-raised meat, regardless of any other ingredients in this product."
            return ProductGradeResult(
                purityGrade: "F",
                puritySummary: "Overridden: this contains cell-cultivated meat.",
                purityNotes: [overrideNote],
                nourishmentGrade: "F",
                nourishmentSummary: "Overridden: this contains cell-cultivated meat.",
                nourishmentNotes: [overrideNote]
            )
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let missingNote = "No ingredient text was available from the product database."
            return ProductGradeResult(
                purityGrade: "—",
                puritySummary: "This product's label didn't include an ingredient list we could grade.",
                purityNotes: [missingNote],
                nourishmentGrade: "—",
                nourishmentSummary: "This product's label didn't include an ingredient list we could grade.",
                nourishmentNotes: [missingNote]
            )
        }

        let items = topLevelIngredients(from: text)
        let (purityGrade, puritySummary, purityNotes, deductions) = gradePurity(
            text: text, items: items, isOrganic: isOrganic, labelsTags: labelsTags
        )
        let (nourishmentGrade, nourishmentSummary, nourishmentNotes) = gradeNourishment(
            text: text, items: items, isOrganic: isOrganic, labelsTags: labelsTags, purityDeductions: deductions
        )

        return ProductGradeResult(
            purityGrade: purityGrade,
            puritySummary: puritySummary,
            purityNotes: purityNotes,
            nourishmentGrade: nourishmentGrade,
            nourishmentSummary: nourishmentSummary,
            nourishmentNotes: nourishmentNotes
        )
    }

    // MARK: - Purity scoring

    private static func gradePurity(
        text: String, items: [String], isOrganic: Bool, labelsTags: [String]
    ) -> (grade: String, summary: String, notes: [String], deductions: Int) {
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
        if !unrefinedPalmOilPhrases.contains(where: { text.contains($0) }), let hit = firstMatch(palmOilKeywords, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — packaged food almost always uses industrially refined palm oil, which strips out most of the carotenoids and vitamin E compounds unrefined red palm oil retains; some traditional-health sources that favor tropical fats generally distinguish the unrefined form from this one.")
        }
        if let hit = addedSugarAmongFirstFive(items: items) {
            deductions += 1
            notes.append("\(hit.capitalized) is among the first ingredients listed, meaning it's one of this product's main components by weight, not a trace addition. WHO guidance recommends keeping added sugar under 10% of daily energy intake. This is a note about where it falls in the ingredient list, not a calorie or weight-loss judgment.")
        }
        if let hit = firstMatch(concerningEmulsifiers, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — an emulsifier. Research (a 2015 mouse study, a 2022 controlled human feeding trial, and a 2023 large human cohort study) has linked it to a disrupted gut mucus barrier and microbiome changes; real-world risk at typical intake levels is still being studied.")
        }
        if let hit = firstMatch(artificialSweeteners, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — WHO's cancer research arm (IARC) classified this in 2023 as \"possibly carcinogenic to humans,\" its lowest positive-evidence tier. The same day, WHO's food-safety risk body (JECFA) reaffirmed the existing safe-intake guideline unchanged, finding no convincing evidence of harm at typical consumption. Both findings are real; a hazard classification isn't the same as a real-world risk finding.")
        }
        if let hit = firstMatch(refinedFlour, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — stripped of the bran and germ during milling (and, for the bleached variants, chemically treated afterward). Grounded's lens favors whole or traditionally-milled grain over this level of refinement.")
        }
        if let hit = firstMatch(processedIsolates, in: text) {
            deductions += 1
            notes.append("\(hit.capitalized) — a heavily processed, industrially extracted protein isolate. Real-food sources of the same protein (whole dairy, whole soy, whole grain) aren't flagged; the isolate form is, regardless of what it started as.")
        }
        let eNumberCount = countENumbers(in: text)
        if items.count > 12 || eNumberCount >= 3 {
            deductions += 1
            notes.append("\(items.count) ingredients, including \(eNumberCount) coded/E-number additives — a marker of high processing (per the NOVA food-classification framework) independent of whether any single ingredient here is individually flagged.")
        }

        if !isOrganic, let hit = firstMatch(desiccationRiskCrops, in: text) {
            // Transparency note only — deliberately does not add a deduction.
            notes.append("\(hit.capitalized) (not labeled organic) — this app can't test for pesticide residue directly. Conventional \(hit) is sometimes pre-harvest desiccated with glyphosate in some growing regions; noted for transparency, not as a confirmed finding about this product.")
        }
        if let hit = firstMatch(wholeAnimalFoods, in: text), !isPastureLabeled(labelsTags: labelsTags, text: text) {
            // Also transparency-only — not a deduction, same pattern as the grain note above.
            notes.append("\(hit.capitalized) — not labeled pasture-raised or grass-fed. Most conventional meat/dairy comes from animals raised in confinement on grain-based feed. Noted for transparency; Grounded can't verify actual farming conditions from a barcode.")
        }

        if notes.isEmpty {
            notes.append("No ingredients matched Grounded's current flagged-ingredient list.")
        }

        return (letterGrade(forDeductions: deductions), summary(forDeductions: deductions), notes, deductions)
    }

    // MARK: - Nourishment scoring

    private static func gradeNourishment(
        text: String, items: [String], isOrganic: Bool, labelsTags: [String], purityDeductions: Int
    ) -> (grade: String, summary: String, notes: [String]) {
        var points = 0
        var notes: [String] = []

        // "Primary" ingredients: the first 3 top-level items, ignoring a bare "water" entry
        // (extremely common as ingredient #1 in soups/broths and shouldn't block credit for
        // what's actually driving the product).
        let primaryItems = items.prefix(3).filter { $0 != "water" }

        var animalMatched = false
        for item in primaryItems {
            guard let hit = firstMatch(wholeAnimalFoods, in: item) else { continue }
            // Don't award animal-based credit on the same ingredient that's also getting a
            // purity deduction for being a processed isolate or refined flour — e.g. "whey
            // protein isolate" shouldn't earn credit for being dairy-derived when it's
            // simultaneously being flagged for how processed it is.
            if firstMatch(processedIsolates, in: item) != nil || firstMatch(refinedFlour, in: item) != nil {
                continue
            }
            points += 3
            notes.append("\(hit.capitalized) as a primary ingredient — a whole animal-based food. Grounded's ancestral lens treats these as foundational.")
            animalMatched = true
            if let organHit = firstMatch(organBonusKeywords, in: item) {
                points += 1
                notes.append("\(organHit.capitalized) specifically — organ meat/bone broth carries nutrient density whole muscle meat alone doesn't.")
            }
            break
        }

        if !animalMatched, purityDeductions == 0 {
            for item in primaryItems {
                guard let hit = firstMatch(traditionalPlantFoods, in: item) else { continue }
                points += 2
                notes.append("\(hit.capitalized) as a primary ingredient, with nothing else on this label flagged — a traditional plant food, properly represented. Grounded's lens treats well-prepared plant foods as fine, not something to avoid.")
                break
            }
        }

        if let prepHit = firstMatch(prepMarkers, in: text) {
            points += 1
            notes.append("Traditional preparation noted (\(prepHit)) — fermentation/sprouting/soaking are traditional processing methods, distinct from industrial processing.")
        }

        if items.count <= 5 {
            points += 1
            notes.append("Only \(items.count) ingredient\(items.count == 1 ? "" : "s") — a short, simple list.")
        }

        if isPastureLabeled(labelsTags: labelsTags, text: text) {
            points += 1
            notes.append("Labeled pasture-raised, grass-fed/finished, free-range, or wild-caught.")
        }

        if isOrganic {
            points += 1
            notes.append("Labeled organic.")
        }

        if notes.isEmpty {
            notes.append("Nothing on this label indicates a whole, traditionally-prepared, or animal-based food — Grounded's ancestral lens doesn't award credit here even though nothing was flagged as concerning either.")
        }

        return (nourishmentLetterGrade(forPoints: points), nourishmentSummary(forPoints: points), notes)
    }

    // MARK: - Shared helpers

    private static func firstMatch(_ keywords: [String], in text: String) -> String? {
        keywords.first { text.contains($0) }
    }

    private static func isPastureLabeled(labelsTags: [String], text: String) -> Bool {
        pastureLabels.contains { pl in labelsTags.contains { $0.contains(pl) } } || pastureLabels.contains { text.contains($0) }
    }

    private static func countENumbers(in text: String) -> Int {
        // Most E-numbers are 3 digits (E150, E202); a real subset (mostly modified starches,
        // E1400–E1520) are 4 — matching both so that category isn't systematically missed.
        guard let regex = try? NSRegularExpression(pattern: #"\be\d{3,4}\b"#) else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, range: range)
    }

    // Splits ingredient text on top-level commas only — commas nested inside parentheses
    // (a compound ingredient's own sub-ingredients, e.g. "milk chocolate (sugar, cocoa
    // butter, ...)") don't count as separate top-level items, since ingredient lists are
    // ordered by weight only at the top level, not inside a compound ingredient's own
    // parenthetical breakdown.
    private static func topLevelIngredients(from text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var depth = 0
        for char in text {
            switch char {
            case "(", "[":
                depth += 1
                current.append(char)
            case ")", "]":
                depth = max(0, depth - 1)
                current.append(char)
            case ",":
                if depth == 0 {
                    items.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                } else {
                    current.append(char)
                }
            default:
                current.append(char)
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(trimmed)
        }
        return items
    }

    // Only checks the first 5 top-level ingredients — position-based, not presence-based, so
    // trace sugar deep in a long ingredient list doesn't flag nearly every packaged product.
    private static func addedSugarAmongFirstFive(items: [String]) -> String? {
        for item in items.prefix(5) {
            if traditionalSweeteners.contains(where: { item.contains($0) }) {
                continue
            }
            if let hit = addedSugarKeywords.first(where: { item.contains($0) }) {
                return hit
            }
        }
        return nil
    }

    // v0.3: ten deduction-eligible categories now (seed oils, dyes, preservatives, palm oil,
    // added sugar, concerning emulsifiers, artificial sweeteners, refined flour, processed
    // isolates, ultra-processed marker). Scale unchanged from v0.2 — F was already reachable.
    private static func letterGrade(forDeductions deductions: Int) -> String {
        switch deductions {
        case 0: return "A"
        case 1: return "B"
        case 2: return "C"
        case 3: return "D"
        default: return "F"
        }
    }

    private static func summary(forDeductions deductions: Int) -> String {
        switch deductions {
        case 0: return "No ingredients flagged against Grounded's current criteria."
        case 1: return "One ingredient flagged against Grounded's criteria — see below."
        default: return "\(deductions) ingredients flagged against Grounded's criteria — see below."
        }
    }

    // Points-based, new in v0.3: 0 → F, 1 → D, 2 → C, 3 → B, 4 → A, 5 → A+, 6+ → A++.
    // First-pass thresholds, not derived from anything precise — flagged as adjustable in
    // `claude/barcode-grading-v0.3-spec.md`.
    private static func nourishmentLetterGrade(forPoints points: Int) -> String {
        switch points {
        case 0: return "F"
        case 1: return "D"
        case 2: return "C"
        case 3: return "B"
        case 4: return "A"
        case 5: return "A+"
        default: return "A++"
        }
    }

    private static func nourishmentSummary(forPoints points: Int) -> String {
        switch points {
        case 0: return "Nothing here signals real nutrient density or traditional preparation — being free of flagged ingredients isn't the same as being nourishing."
        case 1...2: return "Some markers of real, traditionally-prepared food — see below."
        default: return "Strong markers of real, ancestral, nutrient-dense food — see below."
        }
    }
}
