import SwiftUI

struct CameraView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var settings: AppSettings

    @State private var isLongPressing = false

    var body: some View {
        ZStack {
            // Completely black background
            Color.black
                .ignoresSafeArea()

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
            }

            // Mode indicator (bottom center)
            VStack {
                Spacer()
                modeIndicator
                    .padding(.bottom, 50)
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .gesture(
            // Combined gesture: tap and long press
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in
                    // Long press began (finger held)
                }
                .onEnded { _ in
                    handleLongPressStart()
                }
                .simultaneously(with:
                    TapGesture()
                        .onEnded {
                            handleTap()
                        }
                )
        )
        .onChange(of: isLongPressing) { pressing in
            if !pressing {
                handleLongPressEnd()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            if settings.captureMode == .photo {
                if pressing {
                    handleLongPressStart()
                } else {
                    handleLongPressEnd()
                }
            }
        }, perform: {})
        .statusBarHidden(true)
    }

    // MARK: - Mode Indicator

    @ViewBuilder
    private var modeIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(settings.captureMode == .photo ? Color.white : Color.red)
                .frame(width: 8, height: 8)
                .modifier(settings.captureMode == .video && cameraManager.isRecording
                          ? PulsingModifier() : PulsingModifier(enabled: false))

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

    private func handleLongPressStart() {
        guard settings.captureMode == .photo, !isLongPressing else { return }
        isLongPressing = true
        cameraManager.startBurst()
    }

    private func handleLongPressEnd() {
        guard isLongPressing else { return }
        isLongPressing = false
        cameraManager.stopBurst()
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
