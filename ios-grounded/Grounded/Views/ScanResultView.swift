import SwiftUI

/// A real, looked-up product: identity from Open Food Facts/Open Beauty Facts, graded by
/// `ProductGrading` against Grounded's own criteria. See `ProductLookupService` and
/// `ProductGrading` for how each half is built, and `claude/barcode-grading-rubric.md` in
/// the project docs for the grading rubric's sourcing.
nonisolated struct ScannedProduct: Identifiable, Hashable {
    let id = UUID()
    let barcode: String
    let name: String
    let brand: String
    let category: String
    let sourceLabel: String
    let sourceURL: String
    let grade: String
    let gradeSummary: String
    let notedIngredients: [String]
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
                        Text("Grades are Grounded's own read on the label against our current criteria — not a medical, safety, or regulatory judgement about this product.")
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
                    .accessibilityIdentifier("scanResult.productName")
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
        VStack(alignment: .leading, spacing: 14) {
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

            Divider()
                .overlay(Theme.hairline)

            // Attribution required by Open Food Facts / Open Beauty Facts' license terms
            // (ODbL / CC-BY-SA) — kept on the result itself, not tucked into an About page.
            Link(destination: URL(string: product.sourceURL) ?? URL(string: "https://openfoodfacts.org")!) {
                HStack(spacing: 6) {
                    Text("Product data from \(product.sourceLabel)")
                        .captionText(12, color: Theme.creamFaint)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.creamFaint)
                }
            }
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
