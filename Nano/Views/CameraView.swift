import SwiftUI

struct CameraView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings

    @State private var isPressing = false
    @State private var longPressTask: Task<Void, Never>?

    private let burstHoldDuration: UInt64 = 400_000_000

    init(selectedTab: Binding<Int> = .constant(1)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            Color.black
        }
        .ignoresSafeArea()
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in handlePressBegan() }
                .onEnded { _ in handlePressEnded() }
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
        .overlay(alignment: .bottom) {
            if cameraManager.isBursting {
                Text("\(cameraManager.burstCount)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(.bottom, 110)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: cameraManager.isBursting)
        .statusBarHidden(true)
    }

    private var captureError: String? {
        cameraManager.captureErrorMessage ?? galleryStore.saveErrorMessage
    }

    // MARK: - Gesture Handlers

    private func handlePressBegan() {
        guard selectedTab == 1, !isPressing else { return }
        isPressing = true

        longPressTask = Task {
            try? await Task.sleep(nanoseconds: burstHoldDuration)
            guard !Task.isCancelled, isPressing else { return }
            guard settings.captureMode == .photo, !cameraManager.isRecording else { return }
            cameraManager.startBurst()
        }
    }

    private func handlePressEnded() {
        longPressTask?.cancel()
        longPressTask = nil
        guard isPressing else { return }
        isPressing = false

        if cameraManager.isBursting {
            cameraManager.stopBurst()
        } else {
            handleTap()
        }
    }

    private func handleTap() {
        guard selectedTab == 1 else { return }
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
