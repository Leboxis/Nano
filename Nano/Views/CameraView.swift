import SwiftUI

struct CameraView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            Color.black
        }
        .ignoresSafeArea()
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.3, pressing: { isPressing in
            if isPressing {
                if settings.captureMode == .photo {
                    cameraManager.startBurst()
                }
            } else {
                if settings.captureMode == .photo {
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
