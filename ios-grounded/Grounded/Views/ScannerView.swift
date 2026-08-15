import AVFoundation
import SwiftUI

/// Camera-based product scanner. A detected or manually entered code is looked up against
/// Open Food Facts / Open Beauty Facts and graded by `ProductGrading` — see
/// `ProductLookupService` for the lookup and `ScanNotFoundView` for the not-found path.
struct ScannerView: View {
    @State private var scanner = BarcodeScanner()
    @State private var scannedProduct: ScannedProduct?
    @State private var notFoundBarcode: String?
    @State private var isLookingUp = false
    @State private var lookupErrorMessage: String?
    @State private var isEnteringCode = false
    private let lookupService = ProductLookupService()

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .fill(Theme.surface)

                switch scanner.status {
                case .running:
                    CameraPreview(session: scanner.session)
                        .clipShape(.rect(cornerRadius: Theme.radiusLarge, style: .continuous))
                        .overlay { ReticleOverlay() }
                case .permissionDenied:
                    stateMessage(
                        icon: "lock.shield",
                        title: "Camera access is off",
                        body: "Grounded needs the camera to read a barcode. Turn it on in Settings › Grounded.",
                        actionTitle: "Open Settings"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                case .noCameraAvailable:
                    stateMessage(
                        icon: "camera.metering.unknown",
                        title: "No camera found",
                        body: "Connect or enable a camera to scan a product barcode.",
                        actionTitle: nil,
                        action: nil
                    )
                case .failed:
                    stateMessage(
                        icon: "exclamationmark.circle",
                        title: "Camera unavailable",
                        body: "Something interrupted the camera session. Try again.",
                        actionTitle: "Retry"
                    ) {
                        Task { await scanner.start() }
                    }
                case .idle:
                    VStack(spacing: 14) {
                        SkeletonBar(width: 140, height: 14)
                        SkeletonBar(width: 96, height: 14)
                    }
                }

                if isLookingUp {
                    lookupOverlay
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .ambientElevation(.raised)

            footer
        }
        .padding(.bottom, 12)
        .task {
            await scanner.start()
        }
        .onDisappear { scanner.stop() }
        .onChange(of: scanner.lastScannedCode) { _, code in
            guard let code else { return }
            lookUp(barcode: code)
        }
        // `onDismiss` (not the button closures) is what re-arms scanning — it fires on every
        // dismissal path, including a swipe-down, whereas the closures below only fire when
        // the user taps a button inside the sheet. Relying on the closures alone left the
        // scanner stuck any time someone swiped a result away instead of tapping a button.
        .sheet(item: $scannedProduct, onDismiss: { scanner.resumeScanning() }) { product in
            ScanResultView(product: product) {
                scannedProduct = nil
            }
        }
        .sheet(
            isPresented: Binding(
                get: { notFoundBarcode != nil },
                set: { if !$0 { notFoundBarcode = nil } }
            ),
            onDismiss: { scanner.resumeScanning() }
        ) {
            ScanNotFoundView(barcode: notFoundBarcode ?? "") {
                notFoundBarcode = nil
            }
        }
        .sheet(isPresented: $isEnteringCode) {
            ManualCodeSheet { code in
                isEnteringCode = false
                lookUp(barcode: code)
            }
        }
        .alert(
            "Couldn't look that up",
            isPresented: Binding(
                get: { lookupErrorMessage != nil },
                set: { if !$0 { lookupErrorMessage = nil } }
            )
        ) {
            Button("OK") {
                lookupErrorMessage = nil
                scanner.resumeScanning()
            }
        } message: {
            Text(lookupErrorMessage ?? "")
        }
    }

    private var lookupOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 10) {
                ProgressView()
                    .tint(Theme.cream)
                Text("Looking up product…")
                    .captionText(13, color: Theme.cream)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.radiusLarge, style: .continuous))
    }

    /// Looks the code up and routes to the found, not-found, or network-error outcome.
    /// The scanner naturally stops delivering new codes once one is detected (its metadata
    /// delegate clears itself), so no explicit pause is needed here — only `resumeScanning()`
    /// on the way back out, from whichever outcome the user dismisses.
    private func lookUp(barcode: String) {
        guard !isLookingUp else { return }
        isLookingUp = true
        // A manually-entered code always wins if a camera lookup's sheet is still pending —
        // closing it here means at most one sheet is ever driven at a time, so the two
        // independently-presented sheets (found vs. not-found) can't both try to appear.
        isEnteringCode = false
        Task {
            defer { isLookingUp = false }
            do {
                let result = try await lookupService.lookup(barcode: barcode)
                let graded = ProductGrading.grade(ingredientsText: result.ingredientsText, isOrganic: result.isOrganic)
                scannedProduct = ScannedProduct(
                    barcode: barcode,
                    name: result.name,
                    brand: result.brand,
                    category: result.category,
                    sourceLabel: result.source.rawValue,
                    sourceURL: result.source.attributionURL,
                    grade: graded.grade,
                    gradeSummary: graded.summary,
                    notedIngredients: graded.notedIngredients
                )
            } catch ProductLookupError.notFound {
                notFoundBarcode = barcode
            } catch {
                lookupErrorMessage = "We couldn't reach the product database. Check your connection and try again."
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scan a product")
                .screenHeadline(28)
                .foregroundStyle(Theme.cream)
            Text("Point at a barcode on food or cosmetics to look it up")
                .captionText(13)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Grounded looks products up against open product databases and grades what's on the label — this is educational, not a medical or safety verdict.")
                .captionText(12, italic: true)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            QuietButton(title: "Enter a code manually", systemImage: "keyboard") {
                isEnteringCode = true
            }
            .disabled(isLookingUp)
            .opacity(isLookingUp ? 0.5 : 1)
            .accessibilityIdentifier("scanner.enterCodeManually")
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func stateMessage(
        icon: String,
        title: String,
        body: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.creamMuted)
            Text(title)
                .screenHeadline(24)
                .foregroundStyle(Theme.cream)
            Text(body)
                .captionText(13)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                QuietButton(title: actionTitle, action: action)
                    .padding(.top, 6)
                    .frame(maxWidth: 220)
            }
        }
        .padding(28)
    }
}

private struct ReticleOverlay: View {
    @State private var isSweeping = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.74
            let height = width * 0.55

            ZStack {
                Color.black.opacity(0.28)
                    .reverseMask {
                        RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                            .frame(width: width, height: height)
                    }

                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.cream.opacity(0.85), lineWidth: 2)
                    .frame(width: width, height: height)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Theme.cream.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: 2)
                    .offset(y: isSweeping ? height / 2 - 12 : -height / 2 + 12)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isSweeping)

                Text("Align the barcode")
                    .uiLabel(13)
                    .foregroundStyle(Theme.cream.opacity(0.85))
                    .offset(y: height / 2 + 26)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { isSweeping = true }
        }
        .allowsHitTesting(false)
    }
}

/// Real keyboard entry for a barcode, used when the camera can't get a read.
private struct ManualCodeSheet: View {
    let onSubmit: (String) -> Void

    @State private var code: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        let digits = code.filter(\.isNumber)
        return digits.count >= 8 && digits.count <= 14 && digits.count == code.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Enter a code")
                    .screenHeadline(28)
                    .foregroundStyle(Theme.cream)
                Text("Type the digits printed under the barcode")
                    .captionText(13)
            }

            TextField("e.g. 0123456789012", text: $code)
                .bodyText(16)
                .foregroundStyle(Theme.cream)
                .tint(Theme.cream)
                .keyboardType(.numberPad)
                .textContentType(.none)
                .focused($isFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background {
                    Capsule(style: .continuous)
                        .fill(Theme.surface)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.cream.opacity(isFocused ? 0.28 : 0.12), lineWidth: 1)
                }
                .contentShape(.capsule)
                .onTapGesture { isFocused = true }
                .accessibilityIdentifier("manualCode.textField")

            PrimaryButton(title: "Look up code", isEnabled: isValid) {
                onSubmit(code)
            }
            .accessibilityIdentifier("manualCode.submit")

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .presentationDetents([.height(300)])
        .task {
            // Small beat so the sheet finishes presenting before focus is taken,
            // otherwise the keyboard is dismissed by the presentation animation.
            try? await Task.sleep(for: .milliseconds(350))
            isFocused = true
        }
    }
}

extension View {
    fileprivate func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}
