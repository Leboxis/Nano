import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
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
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                // Camera page: dim to minimum
                UIScreen.main.brightness = 0.0
            } else {
                // Gallery or Settings: 50% brightness
                UIScreen.main.brightness = 0.5
            }
        }
        .onAppear {
            // Start on camera = dim
            UIScreen.main.brightness = 0.0
        }
    }
}
