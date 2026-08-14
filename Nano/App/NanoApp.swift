import SwiftUI
import AVFoundation

@main
struct NanoApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var galleryStore = GalleryStore()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var settings = AppSettings()

    // Store original system brightness before opening app
    @State private var originalSystemBrightness: CGFloat = UIScreen.main.brightness

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(galleryStore)
                .environmentObject(cameraManager)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Save initial brightness
                    originalSystemBrightness = UIScreen.main.brightness

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
