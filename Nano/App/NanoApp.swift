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
                    // Configure AVAudioSession to allow haptics/vibrations while camera & mic are active
                    do {
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
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
