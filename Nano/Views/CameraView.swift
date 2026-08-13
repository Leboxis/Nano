import SwiftUI

struct CameraView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var settings: AppSettings

    @State private var isBursting = false

    var body: some View {
        ZStack {
            // Completely black background
            Color.black
        }
        .ignoresSafeArea()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    let distance = hypot(value.translation.width, value.translation.height)
                    // Only stationary tap (distance < 15px) triggers capture.
                    // Horizontal swipes to change tabs (distance >= 15px) are ignored!
                    if distance < 15 {
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
