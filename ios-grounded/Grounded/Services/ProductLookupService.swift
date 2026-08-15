import Foundation

nonisolated enum ProductLookupError: Error {
    /// The barcode isn't in either database. Distinct from `.network` so the UI can show
    /// the calm "we don't have this yet" state instead of an error.
    case notFound
    case network
}

/// Looks a barcode up against Open Food Facts (food) first, then Open Beauty Facts
/// (cosmetics) if food has no match. The two projects are separate databases sharing the
/// same barcode format (EAN/UPC) but covering disjoint products; food coverage is
/// meaningfully better per the sourcing research, so checking it first is the sane default.
/// See `claude/barcode-data-source-research.md` in the project docs for the full sourcing
/// writeup this is built from — free, no API key, commercial use permitted, attribution to
/// the matched source required (see the credit line `ScanResultView` renders per result).
///
/// IMPORTANT: this was written entirely from the two projects' published API docs — the
/// sandbox this was built in cannot reach openfoodfacts.org or openbeautyfacts.org (network
/// egress is allowlisted to a small set of domains and neither is on it), so none of this
/// has been exercised against a real response. The first real scan on a device is the first
/// real test. If field names or response shape have drifted from the documented v2 API,
/// that's where it'll show up.
nonisolated struct ProductLookupService {
    enum Source: String {
        case openFoodFacts = "Open Food Facts"
        case openBeautyFacts = "Open Beauty Facts"

        /// Attribution link required by both projects' license terms (ODbL/CC-BY-SA) —
        /// shown on every result screen, not just tucked into an About page.
        var attributionURL: String {
            switch self {
            case .openFoodFacts: return "https://world.openfoodfacts.org"
            case .openBeautyFacts: return "https://world.openbeautyfacts.org"
            }
        }
    }

    struct Result {
        let source: Source
        let name: String
        let brand: String
        let category: String
        /// English ingredient text ONLY — empty when English text couldn't be confirmed. See
        /// `ingredientsUnavailableInEnglish` for why this is empty in that case, distinct from
        /// a product that genuinely has no ingredient data at all.
        let ingredientsText: String
        /// True when Open Food Facts has ingredient data for this product, but it's not
        /// confirmed to be in English — e.g. a product entered by French contributors with no
        /// English translation yet. Found via a real scan (2026-08-16): Open Food Facts's
        /// generic `ingredients_text` field mirrors whatever language the product was
        /// originally entered in, not a normalized English string — a Nutella scan came back
        /// with French text ("Sucre, Huile de palme, ..."), which every English keyword match
        /// silently failed against, so the product wrongly graded as clean. Grading blind
        /// against unconfirmed-language text is worse than showing no grade, so this flag lets
        /// `ProductGrading` show an honest "can't verify in English yet" state instead of a
        /// false-clean grade.
        let ingredientsUnavailableInEnglish: Bool
        let isOrganic: Bool
        /// Raw, lowercased `labels_tags` from the API — v0.2 only ever collapsed this down to
        /// the single `isOrganic` boolean, but v0.3's grading needs to check for several other
        /// label values (pasture-raised, grass-fed, grass-finished, free-range, wild-caught),
        /// so `ProductGrading` now does its own tag matching against the full array instead of
        /// this service pre-deciding which tags matter.
        let labelsTags: [String]
    }

    /// Both APIs require a descriptive User-Agent instead of an API key. TODO before
    /// launch: swap in a real support address — this placeholder is not monitored.
    private static let userAgent = "Grounded-iOS/0.1 (contact: support@groundedapp.example)"
    // `ingredients_text_en` and `ingredients_lc` added after a real scan showed the generic
    // `ingredients_text` field isn't reliably English — see `Result.ingredientsUnavailableInEnglish`.
    private static let fields = "product_name,brands,categories,ingredients_text,ingredients_text_en,ingredients_lc,labels_tags"

    func lookup(barcode: String) async throws -> Result {
        if let food = try? await fetch(host: "world.openfoodfacts.org", barcode: barcode, source: .openFoodFacts) {
            return food
        }
        // Only the food lookup's failure is swallowed above (falls through to try
        // cosmetics) — a failure here is the real, final result for this scan.
        return try await fetch(host: "world.openbeautyfacts.org", barcode: barcode, source: .openBeautyFacts)
    }

    private func fetch(host: String, barcode: String, source: Source) async throws -> Result {
        // Real EAN/UPC barcodes are digits only — filtering to digits both sanitizes the
        // value for URL interpolation and rejects garbage before it ever reaches the network.
        let safeBarcode = barcode.filter(\.isNumber)
        guard !safeBarcode.isEmpty,
              let url = URL(string: "https://\(host)/api/v2/product/\(safeBarcode).json?fields=\(Self.fields)") else {
            throw ProductLookupError.network
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProductLookupError.network
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProductLookupError.network
        }

        guard let decoded = try? JSONDecoder().decode(APIResponse.self, from: data),
              decoded.status == 1, let product = decoded.product else {
            throw ProductLookupError.notFound
        }

        guard let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            // A product entry with no name is effectively useless to show — treat it the
            // same as not found rather than surfacing a blank result.
            throw ProductLookupError.notFound
        }

        let labelsTags = (product.labelsTags ?? []).map { $0.lowercased() }

        // Resolve which ingredient text (if any) is confirmed English. Priority: an explicit
        // English translation (`ingredients_text_en`) if present; else the generic field, but
        // ONLY if `ingredients_lc` confirms it's actually English; otherwise there's real
        // ingredient data we just can't safely keyword-match against.
        let rawIngredients = (product.ingredientsText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let englishIngredients = (product.ingredientsTextEn ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedIngredientsText: String
        let unavailableInEnglish: Bool
        if !englishIngredients.isEmpty {
            resolvedIngredientsText = englishIngredients
            unavailableInEnglish = false
        } else if product.ingredientsLc?.lowercased() == "en" {
            resolvedIngredientsText = rawIngredients
            unavailableInEnglish = false
        } else if !rawIngredients.isEmpty {
            resolvedIngredientsText = ""
            unavailableInEnglish = true
        } else {
            resolvedIngredientsText = ""
            unavailableInEnglish = false
        }

        return Result(
            source: source,
            name: name,
            brand: product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Unknown brand",
            // The category list runs general → specific; the last tag is usually the most
            // specific one, which reads better as a single chip than the broadest category.
            category: product.categories?.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces) ?? "Uncategorized",
            ingredientsText: resolvedIngredientsText,
            ingredientsUnavailableInEnglish: unavailableInEnglish,
            isOrganic: labelsTags.contains { $0.contains("organic") },
            labelsTags: labelsTags
        )
    }

    private struct APIResponse: Decodable {
        let status: Int
        let product: APIProduct?
    }

    private struct APIProduct: Decodable {
        let productName: String?
        let brands: String?
        let categories: String?
        let ingredientsText: String?
        let ingredientsTextEn: String?
        let ingredientsLc: String?
        let labelsTags: [String]?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case categories
            case ingredientsText = "ingredients_text"
            case ingredientsTextEn = "ingredients_text_en"
            case ingredientsLc = "ingredients_lc"
            case labelsTags = "labels_tags"
        }
    }
}
