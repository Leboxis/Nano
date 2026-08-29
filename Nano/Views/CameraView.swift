import SwiftUI

struct CameraView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var galleryStore: GalleryStore
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
        .overlay(alignment: .top) {
            if let message = captureError {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.red.opacity(0.75)))
                    .padding(.top, 56)
                    .transition(.opacity)
                    .task(id: captureError) {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        cameraManager.captureErrorMessage = nil
                        galleryStore.saveErrorMessage = nil
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: captureError)
        .statusBarHidden(true)
    }

    private var captureError: String? {
        cameraManager.captureErrorMessage ?? galleryStore.saveErrorMessage
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
