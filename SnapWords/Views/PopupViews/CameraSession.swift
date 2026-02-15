import AVFoundation
import UIKit
import LensCore

@MainActor
@Observable
final class CameraSession: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.snapwords.ocr", qos: .userInitiated)
    private var isConfigured = false
    private var isOCRProcessing = false
    private var lastOCRDate = Date.distantPast
    private let ocrInterval: TimeInterval = 1.5
    var isRunning = false
    var latestTokens: [RecognizedToken] = []
    var frozenImage: UIImage?
    var onTokensUpdated: (([RecognizedToken]) -> Void)?

    func start() {
        guard !isRunning else { return }

        if !isConfigured {
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            session.commitConfiguration()
            isConfigured = true
        }

        frozenImage = nil
        let captureSession = session
        Task.detached {
            captureSession.startRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = true
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        let captureSession = session
        Task.detached {
            captureSession.stopRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = false
            }
        }
    }

    /// Freeze the current frame and return it as a UIImage. Stops real-time OCR.
    func freezeAndCapture() -> UIImage? {
        return frozenImage
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Save the latest frame for freeze
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            Task { @MainActor [weak self] in
                self?.frozenImage = uiImage
            }
        }

        // Throttle OCR — skip if already processing or too soon
        let session = self
        Task { @MainActor in
            guard !session.isOCRProcessing else { return }
            let now = Date()
            guard now.timeIntervalSince(session.lastOCRDate) >= session.ocrInterval else { return }
            session.isOCRProcessing = true
            session.lastOCRDate = now

            let ocrService = OCRService()
            let ocrLanguage = LanguageSettings().targetLanguage
            do {
                let tokens = try await ocrService.recognizeTokens(from: pixelBuffer, language: ocrLanguage)
                session.latestTokens = tokens
                session.onTokensUpdated?(tokens)
            } catch {
                // OCR failed silently
            }
            session.isOCRProcessing = false
        }
    }
}
