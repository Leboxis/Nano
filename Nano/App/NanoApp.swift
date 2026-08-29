import SwiftUI
import AVFoundation

@main
struct NanoApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var galleryStore = GalleryStore()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var settings = AppSettings()

    @State private var originalSystemBrightness: CGFloat

    private static let brightnessKey = "nanoOriginalBrightness"

    init() {
        let current = Double(UIScreen.main.brightness)
        let stored = UserDefaults.standard.double(forKey: NanoApp.brightnessKey)

        var resolved = current
        if current < 0.05 {
            resolved = stored > 0.05 ? stored : 0.5
        }

        _originalSystemBrightness = State(initialValue: CGFloat(resolved))
        UserDefaults.standard.set(resolved, forKey: NanoApp.brightnessKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(galleryStore)
                .environmentObject(cameraManager)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Configure AVAudioSession to ALLOW haptics and system sounds during recording (iOS 13+)
                    do {
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.mixWithOthers, .defaultToSpeaker])
                        if #available(iOS 13.0, *) {
                            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
                        }
                        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    } catch {
                        print("NanoApp: Failed to configure AVAudioSession: \(error)")
                    }

                    // Link camera to gallery
                    cameraManager.galleryStore = galleryStore
                    cameraManager.updateMode(settings.captureMode)

                    // Request permissions then start session
                    cameraManager.requestPermissions { granted in
                        if granted {
                            cameraManager.setupSession()
                            cameraManager.startSession()
                        }
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        cameraManager.startSession()
                    case .inactive, .background:
                        // Restore user's original phone brightness when app is minimized/closed!
                        UIScreen.main.brightness = originalSystemBrightness
                        UserDefaults.standard.set(Double(originalSystemBrightness), forKey: NanoApp.brightnessKey)

                        // Stop active recording safely if app goes to background
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                        }
                        cameraManager.stopSession()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
