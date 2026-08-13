import AVFoundation
import UIKit
import SwiftUI

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var captureMode: CaptureMode = .photo
    @Published var isSessionRunning = false

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var audioInput: AVCaptureDeviceInput?

    private let sessionQueue = DispatchQueue(label: "com.nano.camera.session")

    weak var galleryStore: GalleryStore?

    // Burst
    private var burstTimer: Timer?
    private var isBursting = false

    // Settings
    @AppStorage("photoMegapixels") private var photoMegapixels: Int = 12
    @AppStorage("videoQuality") private var videoQuality: String = "1080p"
    @AppStorage("lastMode") private var lastMode: String = "photo"

    override init() {
        super.init()
        captureMode = CaptureMode(rawValue: lastMode) ?? .photo
    }

    // MARK: - Permissions

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        var cameraGranted = false
        var micGranted = false

        let group = DispatchGroup()

        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            cameraGranted = granted
            group.leave()
        }

        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            micGranted = granted
            group.leave()
        }

        group.notify(queue: .main) {
            completion(cameraGranted && micGranted)
        }
    }

    // MARK: - Session Setup

    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.beginConfiguration()

            // Camera input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("CameraManager: No back camera available")
                session.commitConfiguration()
                return
            }
            self.currentCamera = camera

            do {
                let videoInput = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                }
            } catch {
                print("CameraManager: Failed to create video input: \(error)")
                session.commitConfiguration()
                return
            }

            // Audio input
            if let mic = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: mic)
                    if session.canAddInput(audioInput) {
                        session.addInput(audioInput)
                        self.audioInput = audioInput
                    }
                } catch {
                    print("CameraManager: Failed to create audio input: \(error)")
                }
            }

            // Photo output
            let photoOutput = AVCapturePhotoOutput()
            photoOutput.isHighResolutionCaptureEnabled = true
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.photoOutput = photoOutput
            }

            // Movie output
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                self.movieOutput = movieOutput
            }

            self.configureSessionPreset(session: session)
            session.commitConfiguration()
            self.captureSession = session
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            if !session.isRunning {
                session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            if session.isRunning {
                session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    // MARK: - Configuration

    private func configureSessionPreset(session: AVCaptureSession) {
        switch captureMode {
        case .photo:
            if session.canSetSessionPreset(.photo) {
                session.sessionPreset = .photo
            }
        case .video:
            let preset = videoPreset()
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
            } else if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }
        }
    }

    private func videoPreset() -> AVCaptureSession.Preset {
        switch videoQuality {
        case "480p": return .medium
        case "720p": return .hd1280x720
        case "1080p": return .hd1920x1080
        case "4K": return .hd4K3840x2160
        default: return .hd1920x1080
        }
    }

    func updateMode(_ mode: CaptureMode) {
        captureMode = mode
        lastMode = mode.rawValue

        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            session.beginConfiguration()
            self.configureSessionPreset(session: session)
            session.commitConfiguration()
        }
    }

    func refreshConfiguration() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            session.beginConfiguration()
            self.configureSessionPreset(session: session)
            session.commitConfiguration()
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }

        sessionQueue.async {
            let settings = AVCapturePhotoSettings()

            // Configure resolution based on megapixels
            if let maxDimensions = self.photoDimensions() {
                settings.maxPhotoDimensions = maxDimensions
            }

            settings.isHighResolutionPhotoEnabled = true

            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        // Haptic feedback
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    private func photoDimensions() -> CMVideoDimensions? {
        switch photoMegapixels {
        case 8: return CMVideoDimensions(width: 3264, height: 2448)
        case 12: return CMVideoDimensions(width: 4032, height: 3024)
        case 24: return CMVideoDimensions(width: 5712, height: 4284)
        case 48: return CMVideoDimensions(width: 8064, height: 6048)
        default: return CMVideoDimensions(width: 4032, height: 3024)
        }
    }

    // MARK: - Burst Capture

    func startBurst() {
        guard !isBursting else { return }
        isBursting = true

        DispatchQueue.main.async { [weak self] in
            self?.burstTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.capturePhoto()
            }
        }
    }

    func stopBurst() {
        isBursting = false
        DispatchQueue.main.async { [weak self] in
            self?.burstTimer?.invalidate()
            self?.burstTimer = nil
        }
    }

    // MARK: - Video Recording

    func startRecording() {
        guard let movieOutput = movieOutput, !isRecording else { return }

        // Single vibration to signal recording started
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let tempDir = FileManager.default.temporaryDirectory
            let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).mov")

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }

            movieOutput.startRecording(to: outputURL, recordingDelegate: self)

            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }

    func stopRecording() {
        guard let movieOutput = movieOutput, isRecording else { return }

        sessionQueue.async {
            movieOutput.stopRecording()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("CameraManager: Photo capture error: \(error)")
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            print("CameraManager: No photo data")
            return
        }

        galleryStore?.savePhoto(data: data)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false

            // 4 rapid vibrations to signal recording stopped
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    generator.impactOccurred()
                }
            }
        }

        if let error = error {
            print("CameraManager: Recording error: \(error)")
            return
        }

        galleryStore?.saveVideo(url: outputFileURL)
    }
}
