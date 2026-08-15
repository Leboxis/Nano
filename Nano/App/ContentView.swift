import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
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
            if newTab == 1 {
                // Camera page: 0% brightness
                UIScreen.main.brightness = 0.0
            } else {
                // Gallery or Settings: 75% brightness
                UIScreen.main.brightness = 0.75
            }
        }
        .onAppear {
            cameraManager.galleryStore = galleryStore
            // Start on camera = 0% brightness
            UIScreen.main.brightness = 0.0
        }
    }
}
