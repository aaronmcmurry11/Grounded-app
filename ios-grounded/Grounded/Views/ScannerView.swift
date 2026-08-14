import AVFoundation
import SwiftUI

/// Camera-based product scanner. Camera + scan flow only — ingredient grading is
/// designed later, so the result screen shows a clearly-labelled sample read-out.
struct ScannerView: View {
    @State private var scanner = BarcodeScanner()
    @State private var scannedProduct: ScannedProduct?
    @State private var isEnteringCode = false

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
            scannedProduct = ScannedProduct.sample(barcode: code)
        }
        .sheet(item: $scannedProduct) { product in
            ScanResultView(product: product) {
                scannedProduct = nil
                scanner.resumeScanning()
            }
        }
        .sheet(isPresented: $isEnteringCode) {
            ManualCodeSheet { code in
                isEnteringCode = false
                scannedProduct = ScannedProduct.sample(barcode: code)
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
            Text("Ingredient grading is still in design. Scans return a sample read-out for now — treat it as illustrative, not a verdict on any product.")
                .captionText(12, italic: true)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            QuietButton(title: "Enter a code manually", systemImage: "keyboard") {
                isEnteringCode = true
            }
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

            PrimaryButton(title: "Look up code", isEnabled: isValid) {
                onSubmit(code)
            }

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
