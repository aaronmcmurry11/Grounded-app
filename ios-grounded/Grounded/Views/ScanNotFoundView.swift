import SwiftUI

/// Shown when a scanned barcode doesn't match anything in Open Food Facts or Open Beauty
/// Facts. Deliberately calm, not alarming — a barcode miss is common and says nothing about
/// the product itself, so this reads as "we don't have it yet," not an error. Offers an
/// optional manual submission so a real coverage gap can help grow Grounded's own database
/// over time. Follows the fallback-UX spec in `claude/barcode-data-source-research.md`
/// section 7, and mirrors `ReportIssueView`'s on-device-only submission pattern.
struct ScanNotFoundView: View {
    let barcode: String
    let onDismiss: () -> Void

    @Environment(AppModel.self) private var appModel

    @State private var productName: String = ""
    @State private var note: String = ""
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphericBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if didSubmit {
                            confirmation
                        } else {
                            header
                            barcodeRow
                            nameField
                            noteField
                            submit
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(didSubmit ? "Done" : "Close") { onDismiss() }
                        .foregroundStyle(Theme.cream)
                }
            }
        }
        .tint(Theme.cream)
        .presentationBackground(Theme.background)
        .presentationDetents([.large])
    }

    // MARK: Form

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            BotanicalSprig(lineWidth: 1)
                .frame(width: 40, height: 56)
                .opacity(0.5)
            Text("We don't have this one yet")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)
                .accessibilityIdentifier("scanNotFound.title")
            Text("This barcode isn't in the product databases Grounded checks. That's common for newer or smaller-batch products — it isn't a judgement about it either way.")
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }

    private var barcodeRow: some View {
        HStack {
            Text("Barcode")
                .sectionEyebrow(12)
            Spacer()
            Text(barcode)
                .bodyText(15)
                .foregroundStyle(Theme.cream)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product name (optional)")
                .sectionEyebrow()

            TextField("What's it called?", text: $productName)
                .bodyText(15)
                .foregroundStyle(Theme.cream)
                .tint(Theme.cream)
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

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anything else (optional)")
                .sectionEyebrow()

            TextField("Brand, where you found it, ingredient list — anything helps", text: $note, axis: .vertical)
                .bodyText(15)
                .foregroundStyle(Theme.cream)
                .tint(Theme.cream)
                .lineLimit(4...8)
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

    private var submit: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Send this to Grounded", systemImage: "paperplane") {
                appModel.submitProductSubmission(barcode: barcode, productName: productName, note: note)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    didSubmit = true
                }
            }

            QuietButton(title: "Skip and scan another") { onDismiss() }

            Text("Submissions are kept on this device. Grounded has no submission server yet, so nothing is sent anywhere — this queue is here so what you write isn't lost when it goes live.")
                .captionText(12, color: Theme.creamFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: Confirmation

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 14) {
            BotanicalSprig(lineWidth: 1)
                .frame(width: 48, height: 66)
                .opacity(0.5)
            Text("Saved on this device")
                .screenHeadline(24)
                .foregroundStyle(Theme.cream)
            Text("Thanks — this is stored locally and hasn't been sent anywhere, since there's nowhere to send it yet.")
                .bodyText(15)
                .foregroundStyle(Theme.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Scan another") { onDismiss() }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Theme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
        .padding(.top, 20)
        .transition(.opacity.combined(with: .offset(y: 10)))
    }
}
