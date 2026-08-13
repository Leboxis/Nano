import SwiftUI

struct CameraView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var settings: AppSettings

    @State private var touchStartTab: Int = 1
    @State private var isTouching = false

    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            Color.black
        }
        .ignoresSafeArea()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isTouching {
                        isTouching = true
                        touchStartTab = selectedTab
                    }
                }
                .onEnded { value in
                    isTouching = false
                    let distance = hypot(value.translation.width, value.translation.height)
                    // Strict tap check:
                    // 1. Distance < 5px (stationary tap, not a swipe gesture)
                    // 2. Currently on camera tab (selectedTab == 1)
                    // 3. Started touch on camera tab (touchStartTab == 1)
                    if distance < 5 && selectedTab == 1 && touchStartTab == 1 {
                        handleTap()
                    }
                }
        )
        .statusBarHidden(true)
    }

    // MARK: - Gesture Handlers

    private func handleTap() {
        switch settings.captureMode {
        case .photo:
            cameraManager.capturePhoto()
        case .video:
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            } else {
                cameraManager.startRecording()
            }
        }
    }
}
