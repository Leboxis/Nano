import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var isSelectingInGallery = false
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView(selection: $selectedTab) {
            GalleryView(isSelecting: $isSelectingInGallery)
                .tag(0)

            CameraView()
                .tag(1)

            SettingsView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .modifier(DisablePageScrollModifier(disabled: isSelectingInGallery))
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
            // Start on camera = 0% brightness
            UIScreen.main.brightness = 0.0
        }
    }
}

// MARK: - Lock Tab Page Scrolling Modifier

struct DisablePageScrollModifier: ViewModifier {
    var disabled: Bool

    func body(content: Content) -> some View {
        content
            .background(PageScrollLocker(disabled: disabled))
    }
}

struct PageScrollLocker: UIViewRepresentable {
    var disabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var parent: UIView? = uiView.superview
            while parent != nil {
                if let scrollView = parent as? UIScrollView {
                    scrollView.isScrollEnabled = !disabled
                    break
                }
                parent = parent?.superview
            }
        }
    }
}
