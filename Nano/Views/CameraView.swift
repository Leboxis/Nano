import SwiftUI

struct CameraView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var settings: AppSettings

    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            Color.black
        }
        .ignoresSafeArea()
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    // Only capture if user is on the camera tab and performed a clean tap (not a swipe)
                    if selectedTab == 1 {
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
