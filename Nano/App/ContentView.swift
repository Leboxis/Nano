import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView(selection: $selectedTab) {
            GalleryView(selectedTab: $selectedTab)
                .tag(0)

            CameraView(selectedTab: $selectedTab)
                .tag(1)

            SettingsView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        .ignoresSafeArea()
        .onChange(of: selectedTab) { newTab in
            let stored = UserDefaults.standard.double(forKey: "nanoOriginalBrightness")
            let original = stored > 0.05 ? CGFloat(stored) : CGFloat(0.5)

            if newTab == 1 {
                // Camera page: lowest possible brightness
                UIScreen.main.brightness = 0.0
            } else {
                // Gallery or Settings: restore user's original brightness
                UIScreen.main.brightness = original
            }
        }
        .onChange(of: scenePhase) { phase in
            // Re-dim when coming back to the foreground while on the camera tab
            if phase == .active && selectedTab == 1 {
                UIScreen.main.brightness = 0.0
            }
        }
        .onAppear {
            cameraManager.galleryStore = galleryStore
            // Start on camera = 0% brightness
            UIScreen.main.brightness = 0.0
        }
    }
}
