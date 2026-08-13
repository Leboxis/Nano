import AVFoundation
import UIKit
import SwiftUI
import AudioToolbox
import UniformTypeIdentifiers

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var captureMode: CaptureMode = .photo
    @Published var isSessionRunning = false

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentCamera: AVCaptureDevice?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    private let sessionQueue = DispatchQueue(label: "com.nano.camera.session")
    private let defaults = UserDefaults.standard

    weak var galleryStore: GalleryStore?

    // Burst
    private var isBursting = false

    override init() {
        super.init()
        defaults.register(defaults: [
            "vibrationsEnabled": true,
            "photoMegapixels": 24,
            "videoQuality": "4K",
            "videoFPS": 60,
            "zoomLevel": 1,
            "useFrontCamera": false,
            "lastMode": "photo"
        ])
        let lastMode = defaults.string(forKey: "lastMode") ?? "photo"
        captureMode = CaptureMode(rawValue: lastMode) ?? .photo
    }

    // MARK: - UserDefaults Helpers

    private var photoMegapixels: Int {
        let val = defaults.integer(forKey: "photoMegapixels")
        return val > 0 ? val : 24
    }

    private var videoQuality: String {
        defaults.string(forKey: "videoQuality") ?? "4K"
    }

    private var videoFPS: Int {
        let val = defaults.integer(forKey: "videoFPS")
        return val > 0 ? val : 60
    }

    private var zoomLevel: Int {
        let val = defaults.integer(forKey: "zoomLevel")
        return val > 0 ? val : 1
    }

    private var vibrationsEnabled: Bool {
        defaults.object(forKey: "vibrationsEnabled") as? Bool ?? true
    }

    private var useFrontCamera: Bool {
        defaults.bool(forKey: "useFrontCamera")
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
            session.automaticallyConfiguresApplicationAudioSession = false

            // Explicitly allow haptics & system sounds during recording
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.mixWithOthers, .defaultToSpeaker])
                if #available(iOS 13.0, *) {
                    try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
                }
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("CameraManager: Failed to configure audio session: \(error)")
            }

            // Camera input
            let position: AVCaptureDevice.Position = self.useFrontCamera ? .front : .back
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                print("CameraManager: No camera available")
                session.commitConfiguration()
                return
            }
            self.currentCamera = camera

            do {
                let videoInput = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                    self.currentVideoInput = videoInput
                }
            } catch {
                print("CameraManager: Failed to create video input: \(error)")
                session.commitConfiguration()
                return
            }

            // Audio input
            if let mic = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioIn = try AVCaptureDeviceInput(device: mic)
                    if session.canAddInput(audioIn) {
                        session.addInput(audioIn)
                        self.audioInput = audioIn
                    }
                } catch {
                    print("CameraManager: Failed to create audio input: \(error)")
                }
            }

            // Photo output
            let photoOut = AVCapturePhotoOutput()
            if session.canAddOutput(photoOut) {
                session.addOutput(photoOut)
                self.photoOutput = photoOut

                // Unlock maximum supported photo dimensions on photoOutput (iOS 16+)
                if #available(iOS 16.0, *) {
                    if let maxSupported = camera.activeFormat.supportedMaxPhotoDimensions.last {
                        photoOut.maxPhotoDimensions = maxSupported
                        print("CameraManager: Configured photoOutput maxPhotoDimensions: \(maxSupported.width)x\(maxSupported.height)")
                    }
                }
            }

            // Movie output
            let movieOut = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOut) {
                session.addOutput(movieOut)
                self.movieOutput = movieOut
            }

            self.applySessionPreset(session: session)
            session.commitConfiguration()
            self.captureSession = session

            // Apply zoom & video format/FPS after session configuration
            self.applyZoomNow()
            if self.captureMode == .video {
                self.applyVideoFormatAndFPS()
            }
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

    // MARK: - Session Preset & Formats

    private func applySessionPreset(session: AVCaptureSession) {
        switch captureMode {
        case .photo:
            if session.canSetSessionPreset(.photo) {
                session.sessionPreset = .photo
            }
        case .video:
            let preset = videoPresetForQuality(videoQuality)
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
            } else if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }
        }
    }

    private func videoPresetForQuality(_ quality: String) -> AVCaptureSession.Preset {
        switch quality {
        case "480p": return .medium
        case "720p": return .hd1280x720
        case "1080p": return .hd1920x1080
        case "4K": return .hd4K3840x2160
        default: return .hd4K3840x2160
        }
    }

    private func applyVideoFormatAndFPS() {
        guard let camera = currentCamera, let session = captureSession else { return }
        guard captureMode == .video else { return }

        let targetFPS = Double(self.videoFPS)
        let quality = self.videoQuality

        let targetWidth: Int32
        switch quality {
        case "4K": targetWidth = 3840
        case "1080p": targetWidth = 1920
        case "720p": targetWidth = 1280
        case "480p": targetWidth = 640
        default: targetWidth = 3840
        }

        do {
            try camera.lockForConfiguration()

            var bestFormat: AVCaptureDevice.Format?
            var highestFPSFormat: AVCaptureDevice.Format?
            var maxFPSFound: Double = 30.0

            for format in camera.formats {
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let isMatchingResolution = (quality == "4K" ? dims.width >= 3840 : dims.width == targetWidth)

                if isMatchingResolution {
                    for range in format.videoSupportedFrameRateRanges {
                        if range.maxFrameRate > maxFPSFound {
                            maxFPSFound = range.maxFrameRate
                            highestFPSFormat = format
                        }
                        if targetFPS >= range.minFrameRate && targetFPS <= range.maxFrameRate {
                            bestFormat = format
                            break
                        }
                    }
                }
                if bestFormat != nil { break }
            }

            let formatToUse = bestFormat ?? highestFPSFormat

            if let format = formatToUse {
                if session.canSetSessionPreset(.inputPriority) {
                    session.sessionPreset = .inputPriority
                }
                camera.activeFormat = format

                let fpsToSet = min(targetFPS, maxFPSFound)
                let duration = CMTime(value: 1, timescale: Int32(fpsToSet))
                camera.activeVideoMinFrameDuration = duration
                camera.activeVideoMaxFrameDuration = duration
                print("CameraManager: Configured format \(targetWidth)p @ \(fpsToSet) FPS")
            }

            camera.unlockForConfiguration()
        } catch {
            print("CameraManager: Failed to configure video format and FPS: \(error)")
        }
    }

    // MARK: - Public Update Methods

    func updateMode(_ mode: CaptureMode) {
        captureMode = mode
        defaults.set(mode.rawValue, forKey: "lastMode")

        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            session.beginConfiguration()
            self.applySessionPreset(session: session)
            session.commitConfiguration()
            if mode == .video {
                self.applyVideoFormatAndFPS()
            }
        }
    }

    func updateVideoQuality(_ quality: String) {
        defaults.set(quality, forKey: "videoQuality")

        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            session.beginConfiguration()
            let preset = self.videoPresetForQuality(quality)
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
            }
            session.commitConfiguration()
            self.applyVideoFormatAndFPS()
        }
    }

    func updateVideoFPS(_ fps: Int) {
        defaults.set(fps, forKey: "videoFPS")

        sessionQueue.async { [weak self] in
            self?.applyVideoFormatAndFPS()
        }
    }

    func updateMegapixels(_ mp: Int) {
        defaults.set(mp, forKey: "photoMegapixels")
    }

    func refreshConfiguration() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            session.beginConfiguration()
            self.applySessionPreset(session: session)
            session.commitConfiguration()
            if self.captureMode == .video {
                self.applyVideoFormatAndFPS()
            }
        }
    }

    // MARK: - Zoom

    private func applyZoomNow() {
        guard let camera = self.currentCamera else { return }

        let desiredZoom = CGFloat(self.zoomLevel)
        let maxZoom = min(camera.activeFormat.videoMaxZoomFactor, 10.0)
        let clampedZoom = max(1.0, min(desiredZoom, maxZoom))

        do {
            try camera.lockForConfiguration()
            camera.videoZoomFactor = clampedZoom
            camera.unlockForConfiguration()
            print("CameraManager: Zoom set to \(clampedZoom)x")
        } catch {
            print("CameraManager: Failed to set zoom: \(error)")
        }
    }

    func updateZoom(_ level: Int) {
        defaults.set(level, forKey: "zoomLevel")
        sessionQueue.async { [weak self] in
            self?.applyZoomNow()
        }
    }

    // MARK: - Camera Switch (Front/Back)

    func switchCamera(toFront: Bool) {
        defaults.set(toFront, forKey: "useFrontCamera")

        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }

            session.beginConfiguration()

            if let currentInput = self.currentVideoInput {
                session.removeInput(currentInput)
            }

            let position: AVCaptureDevice.Position = toFront ? .front : .back
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                print("CameraManager: No camera for position \(position)")
                session.commitConfiguration()
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newCamera)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    self.currentVideoInput = newInput
                    self.currentCamera = newCamera
                }
            } catch {
                print("CameraManager: Failed to switch camera: \(error)")
            }

            // Update photoOutput maxPhotoDimensions for new camera on iOS 16+
            if #available(iOS 16.0, *), let photoOut = self.photoOutput {
                if let maxSupported = newCamera.activeFormat.supportedMaxPhotoDimensions.last {
                    photoOut.maxPhotoDimensions = maxSupported
                }
            }

            session.commitConfiguration()

            self.applyZoomNow()
            if self.captureMode == .video {
                self.applyVideoFormatAndFPS()
            }
        }
    }

    // MARK: - Haptic Feedback

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard vibrationsEnabled else { return }
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()

            switch style {
            case .light, .soft:
                AudioServicesPlaySystemSound(1519)
            case .medium, .rigid:
                AudioServicesPlaySystemSound(1520)
            case .heavy:
                AudioServicesPlaySystemSound(1521)
            @unknown default:
                AudioServicesPlaySystemSound(1520)
            }
        }
    }

    private func triggerBurstStopHaptic() {
        guard vibrationsEnabled else { return }
        DispatchQueue.main.async {
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.prepare()
                    generator.impactOccurred()
                    AudioServicesPlaySystemSound(1521)
                }
            }
        }
    }

    // MARK: - Native High-Resolution Photo Capture (24 MP & 48 MP Support)

    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            print("CameraManager: photoOutput is nil")
            return
        }

        triggerHaptic(.medium)

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let settings: AVCapturePhotoSettings
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }

            // Request selected Megapixel resolution from activeFormat.supportedMaxPhotoDimensions (iOS 16+)
            if #available(iOS 16.0, *), let camera = self.currentCamera {
                let supportedDims = camera.activeFormat.supportedMaxPhotoDimensions
                let targetMP = self.photoMegapixels

                let desiredWidth: Int32
                switch targetMP {
                case 8: desiredWidth = 3264
                case 12: desiredWidth = 4032
                case 24: desiredWidth = 5712
                case 48: desiredWidth = 8064
                default: desiredWidth = 5712
                }

                var chosenDims = supportedDims.last ?? CMVideoDimensions(width: 4032, height: 3024)
                for dims in supportedDims {
                    if dims.width <= desiredWidth {
                        chosenDims = dims
                    }
                    if dims.width == desiredWidth {
                        chosenDims = dims
                        break
                    }
                }

                settings.maxPhotoDimensions = chosenDims
                print("CameraManager: Capturing photo at \(chosenDims.width)x\(chosenDims.height) for \(targetMP) MP setting")
            }

            // Configure native AVFoundation photo mirroring for front camera
            if let connection = photoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = self.useFrontCamera
                }
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Native Hardware Burst Capture

    func startBurst() {
        guard !isBursting else { return }
        isBursting = true

        sessionQueue.async { [weak self] in
            self?.captureNextBurstPhoto()
        }
    }

    func stopBurst() {
        isBursting = false
        triggerBurstStopHaptic()
    }

    private func captureNextBurstPhoto() {
        guard isBursting, let photoOutput = photoOutput else { return }

        triggerHaptic(.light)

        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.photoQualityPrioritization = .speed

        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = self.useFrontCamera
            }
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Video Recording (Untouched)

    func startRecording() {
        guard let movieOutput = movieOutput, !isRecording else { return }

        triggerHaptic(.heavy)

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            let tempDir = FileManager.default.temporaryDirectory
            let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).mov")

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }

            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = self.useFrontCamera
                }
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

// MARK: - AVCapturePhotoCaptureDelegate (Simple Native Apple Photo Capture)

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("CameraManager: Photo capture error: \(error)")
            return
        }

        // Save native Apple photo representation directly
        if let data = photo.fileDataRepresentation() {
            galleryStore?.savePhoto(data: data)
        }

        // If native burst is active, trigger next frame immediately
        if isBursting {
            sessionQueue.async { [weak self] in
                self?.captureNextBurstPhoto()
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate (Untouched Video)

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.triggerBurstStopHaptic()
        }

        if let error = error {
            print("CameraManager: Recording error: \(error)")
            return
        }

        galleryStore?.saveVideo(url: outputFileURL)
    }
}
