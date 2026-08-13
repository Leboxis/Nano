import SwiftUI

struct CameraView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var settings: AppSettings

    @State private var isBursting = false

    var body: some View {
        ZStack {
            // Completely black background — nothing visible
            Color.black
        }
        .ignoresSafeArea()
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            if settings.captureMode == .photo {
                if pressing && !isBursting {
                    isBursting = true
                    cameraManager.startBurst()
                } else if !pressing && isBursting {
                    isBursting = false
                    cameraManager.stopBurst()
                }
            }
        }, perform: {})
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
