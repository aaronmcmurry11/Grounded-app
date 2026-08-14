import SwiftUI

nonisolated struct ScannedProduct: Identifiable, Hashable {
    let id = UUID()
    let barcode: String
    let name: String
    let brand: String
    let category: String
    /// Placeholder grade. Real grading logic is designed in a later phase.
    let grade: String
    let gradeSummary: String
    let notedIngredients: [String]

    static func sample(barcode: String) -> ScannedProduct {
        ScannedProduct(
            barcode: barcode,
            name: "Oat & Chamomile Body Cream",
            brand: "Sample Brand",
            category: "Cosmetics",
            grade: "B",
            gradeSummary: "Mostly simple ingredients, with one fragrance blend that isn't fully disclosed on the label.",
            notedIngredients: [
                "Colloidal oatmeal — commonly used to soothe dry, itchy skin",
                "Chamomile flower extract — traditionally used on irritated skin",
                "Parfum / fragrance — undisclosed blend, a common contact-irritant source",
                "Phenoxyethanol — preservative, widely permitted at low concentrations",
            ]
        )
    }
}

struct ScanResultView: View {
    let product: ScannedProduct
    let onScanAgain: () -> Void

    var body: some View {
        ZStack {
            AtmosphericBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gradeCard
                    ingredientsCard
                    metaCard

                    VStack(spacing: 12) {
                        PrimaryButton(title: "Scan another", systemImage: "barcode.viewfinder", action: onScanAgain)
                        Text("Grades are illustrative while the ingredient-grading system is being designed. Nothing here is a health or safety judgement about a product.")
                            .captionText(12, color: Theme.creamFaint)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 36)
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }

    private var gradeCard: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 2) {
                // A single display glyph rather than running text, so it sits above the
                // hero band's 42pt ceiling on purpose.
                Text(product.grade)
                    .heroDisplay(48)
                    .foregroundStyle(Theme.onCream)
                Text("Grade")
                    .sectionEyebrow(12, color: Theme.onCream.opacity(0.7))
            }
            .frame(width: 84, height: 96)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.cream)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(product.brand)
                    .sectionEyebrow(12)
                Text(product.name)
                    .screenHeadline(28)
                    .foregroundStyle(Theme.cream)
                    .fixedSize(horizontal: false, vertical: true)
                Text(product.gradeSummary)
                    .bodyText(15)
                    .foregroundStyle(Theme.cream.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Color(hex: 0x5C4423))
        }
        .ambientElevation(.raised)
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What's on the label")
                .sectionEyebrow()
            ForEach(product.notedIngredients, id: \.self) { line in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Theme.creamFaint)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(line)
                        .bodyText(15)
                        .foregroundStyle(Theme.cream.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }

    private var metaCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Barcode")
                    .sectionEyebrow(12)
                Text(product.barcode)
                    .bodyText(15)
                    .foregroundStyle(Theme.cream)
            }
            Spacer()
            Text(product.category)
                .uiLabel(13)
                .foregroundStyle(Theme.cream)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background { Capsule().fill(Theme.cream.opacity(0.08)) }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}
