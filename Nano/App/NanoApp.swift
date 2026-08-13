import SwiftUI
import AVFoundation

@main
struct NanoApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var galleryStore = GalleryStore()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var settings = AppSettings()

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
                        cameraManager.stopSession()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
