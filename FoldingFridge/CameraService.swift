import AVFoundation
import SwiftUI

enum CameraCaptureError: Error {
    case unavailable
    case captureFailed
}

final class CameraService: NSObject, ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isConfigured = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "foldingfridge.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var didConfigureSession = false
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    override init() {
        super.init()
    }

    func requestAccessIfNeeded() {
        switch authorizationStatus {
        case .authorized:
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self.configureSessionIfNeeded()
                    }
                }
            }
        default:
            break
        }
    }

    func configureSessionIfNeeded() {
        guard !didConfigureSession else {
            startSession()
            return
        }

        sessionQueue.async {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }

            do {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                self.session.commitConfiguration()
                self.didConfigureSession = true

                DispatchQueue.main.async {
                    self.isConfigured = true
                }

                self.startSession()
            } catch {
                self.session.commitConfiguration()
            }
        }
    }

    func startSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto() async throws -> UIImage {
        #if targetEnvironment(simulator)
        throw CameraCaptureError.unavailable
        #else
        return try await withCheckedThrowingContinuation { continuation in
            self.captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            HapticManager.captureSound()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
        #endif
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            captureContinuation?.resume(throwing: error)
            captureContinuation = nil
            return
        }

        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            captureContinuation?.resume(throwing: CameraCaptureError.captureFailed)
            captureContinuation = nil
            return
        }

        captureContinuation?.resume(returning: image)
        captureContinuation = nil
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return layer
    }
}
