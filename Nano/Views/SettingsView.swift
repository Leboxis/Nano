import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cameraManager: CameraManager

    @AppStorage("photoMegapixels") private var photoMegapixels: Int = 12
    @AppStorage("videoQuality") private var videoQuality: String = "1080p"
    @AppStorage("videoFPS") private var videoFPS: Int = 30

    private let megapixelOptions = [8, 12, 24, 48]
    private let videoQualityOptions = ["480p", "720p", "1080p", "4K"]
    private let fpsOptions = [30, 60, 90, 120]
    private let zoomOptions = [1, 2, 3]

    var body: some View {
        ZStack {
            Color(red: 0.067, green: 0.067, blue: 0.067)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Title
                    Text("Réglages")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 60)

                    // Mode Section
                    settingsSection(title: "Mode de capture") {
                        Picker("Mode", selection: Binding(
                            get: { settings.captureMode },
                            set: { newMode in
                                settings.captureMode = newMode
                                cameraManager.updateMode(newMode)
                            }
                        )) {
                            Text("Photo").tag(CaptureMode.photo)
                            Text("Vidéo").tag(CaptureMode.video)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Camera Section
                    settingsSection(title: "Caméra") {
                        VStack(alignment: .leading, spacing: 20) {
                            // Front / Back camera
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Objectif")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.6))

                                HStack(spacing: 0) {
                                    optionButton(
                                        label: "Arrière",
                                        isSelected: !settings.useFrontCamera,
                                        action: {
                                            settings.useFrontCamera = false
                                            cameraManager.switchCamera(toFront: false)
                                        }
                                    )
                                    optionButton(
                                        label: "Avant",
                                        isSelected: settings.useFrontCamera,
                                        action: {
                                            settings.useFrontCamera = true
                                            cameraManager.switchCamera(toFront: true)
                                        }
                                    )
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            // Zoom
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Zoom")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.6))

                                HStack(spacing: 0) {
                                    ForEach(zoomOptions, id: \.self) { level in
                                        optionButton(
                                            label: "x\(level)",
                                            isSelected: settings.zoomLevel == level,
                                            action: {
                                                settings.zoomLevel = level
                                                cameraManager.updateZoom(level)
                                            }
                                        )
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Photo Settings
                    if settings.captureMode == .photo {
                        settingsSection(title: "Photo") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mégapixels")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.6))

                                HStack(spacing: 0) {
                                    ForEach(megapixelOptions, id: \.self) { mp in
                                        optionButton(
                                            label: "\(mp) MP",
                                            isSelected: photoMegapixels == mp,
                                            action: {
                                                photoMegapixels = mp
                                                cameraManager.updateMegapixels(mp)
                                            }
                                        )
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Video Settings
                    if settings.captureMode == .video {
                        settingsSection(title: "Vidéo") {
                            VStack(alignment: .leading, spacing: 20) {
                                // Qualité
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Qualité")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.6))

                                    HStack(spacing: 0) {
                                        ForEach(videoQualityOptions, id: \.self) { quality in
                                            optionButton(
                                                label: quality,
                                                isSelected: videoQuality == quality,
                                                action: {
                                                    videoQuality = quality
                                                    cameraManager.updateVideoQuality(quality)
                                                }
                                            )
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                // FPS
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Images par seconde (FPS)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.6))

                                    HStack(spacing: 0) {
                                        ForEach(fpsOptions, id: \.self) { fps in
                                            optionButton(
                                                label: "\(fps)",
                                                isSelected: videoFPS == fps,
                                                action: {
                                                    videoFPS = fps
                                                    cameraManager.updateVideoFPS(fps)
                                                }
                                            )
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Vibrations
                    settingsSection(title: "Retour haptique") {
                        Toggle(isOn: $settings.vibrationsEnabled) {
                            HStack {
                                Image(systemName: settings.vibrationsEnabled
                                      ? "iphone.radiowaves.left.and.right"
                                      : "iphone.slash")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .frame(width: 24)
                                Text("Vibrations")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(Color.white)
                    }

                    // App Info
                    settingsSection(title: "À propos") {
                        VStack(alignment: .leading, spacing: 8) {
                            infoRow(label: "Version", value: "1.0.0")
                            infoRow(label: "Build", value: "1")
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 24)
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Components

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.35))
                .tracking(1.5)

            content()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }

    private func optionButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                              ? Color.white
                              : Color.white.opacity(0.08))
                )
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
        }
    }
}
