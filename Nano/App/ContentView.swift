import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var savedBrightness: CGFloat = UIScreen.main.brightness
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView(selection: $selectedTab) {
            GalleryView()
                .tag(0)

            CameraView()
                .tag(1)

            SettingsView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            // Save current brightness and dim for camera
            savedBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 0.0
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                // Camera page: dim to minimum
                savedBrightness = max(savedBrightness, 0.15)
                UIScreen.main.brightness = 0.0
            } else {
                // Gallery or Settings: restore brightness
                UIScreen.main.brightness = savedBrightness
            }
        }
    }
}
