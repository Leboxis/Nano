import SwiftUI

@main
struct NanoApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var galleryStore = GalleryStore()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var settings = AppSettings()

    private var originalBrightness: CGFloat = UIScreen.main.brightness

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(galleryStore)
                .environmentObject(cameraManager)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Link camera to gallery
                    cameraManager.galleryStore = galleryStore
                    cameraManager.updateMode(settings.captureMode)

                    // Lower brightness to minimum
                    UIScreen.main.brightness = 0.0

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
                        UIScreen.main.brightness = 0.0
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
