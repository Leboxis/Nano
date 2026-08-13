import SwiftUI

struct CameraView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var settings: AppSettings

    @State private var isBursting = false

    var body: some View {
        ZStack {
            // Completely black background
            Color.black

            // Recording indicator (top right, pulsing red dot)
            if cameraManager.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .modifier(PulsingModifier())
                            .padding(.top, 60)
                            .padding(.trailing, 24)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Mode indicator (bottom center)
            VStack {
                Spacer()
                modeIndicator
                    .padding(.bottom, 50)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        // Use onTapGesture — does NOT block TabView horizontal swipe
        .onTapGesture {
            handleTap()
        }
        // Long press for burst — pressing callback tracks press state
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
        }, perform: {
            // Long press completed — burst already started via pressing callback
        })
        .statusBarHidden(true)
    }

    // MARK: - Mode Indicator

    @ViewBuilder
    private var modeIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(settings.captureMode == .photo ? Color.white : Color.red)
                .frame(width: 8, height: 8)
                .modifier(
                    PulsingModifier(
                        enabled: settings.captureMode == .video && cameraManager.isRecording
                    )
                )

            Text(settings.captureMode == .photo ? "PHOTO" : "VIDÉO")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
                .tracking(2)
        }
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

// MARK: - Pulsing Animation Modifier

struct PulsingModifier: ViewModifier {
    var enabled: Bool = true
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        if enabled {
            content
                .opacity(isPulsing ? 0.3 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }
        } else {
            content
        }
    }
}
