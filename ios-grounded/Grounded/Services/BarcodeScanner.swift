import AVFoundation
import Observation
import SwiftUI

nonisolated enum ScannerStatus: Equatable {
    case idle
    case running
    case permissionDenied
    case noCameraAvailable
    case failed
}

/// Live barcode capture session. Grading logic for scanned products is deliberately
/// not implemented in this phase — the session only reports the detected code.
@Observable
final class BarcodeScanner: NSObject {
    private(set) var status: ScannerStatus = .idle
    private(set) var lastScannedCode: String?

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var isConfigured = false

    func start() async {
        let granted = await requestAccess()
        guard granted else {
            status = .permissionDenied
            return
        }
        guard configureIfNeeded() else { return }
        guard !session.isRunning else {
            status = .running
            return
        }
        let session = session
        await Task.detached { session.startRunning() }.value
        status = .running
    }

    func stop() {
        guard session.isRunning else { return }
        let session = session
        Task.detached { session.stopRunning() }
        status = .idle
    }

    func resumeScanning() {
        lastScannedCode = nil
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }

        // `.external` is included so the cloud simulator's injected camera is found.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualWideCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = discovery.devices.first else {
            status = .noCameraAvailable
            return false
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                status = .failed
                return false
            }
            session.addInput(input)
        } catch {
            print("[BarcodeScanner] could not open camera input")
            status = .failed
            return false
        }

        guard session.canAddOutput(metadataOutput) else {
            status = .failed
            return false
        }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        // Only types the active device actually reports are assignable — setting an
        // unsupported type (common with the simulator's injected camera) throws.
        let wanted: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code39, .code128, .qr]
        let supported = metadataOutput.availableMetadataObjectTypes
        metadataOutput.metadataObjectTypes = wanted.filter { supported.contains($0) }

        isConfigured = true
        return true
    }
}

extension BarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        Task { @MainActor in
            guard lastScannedCode == nil else { return }
            lastScannedCode = value
            output.setMetadataObjectsDelegate(nil, queue: nil)
        }
    }
}

/// Thin UIKit bridge for the camera preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return layer
        }
    }
}
