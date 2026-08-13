import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cameraManager: CameraManager

    @AppStorage("photoMegapixels") private var photoMegapixels: Int = 12
    @AppStorage("videoQuality") private var videoQuality: String = "1080p"

    private let megapixelOptions = [8, 12, 24, 48]
    private let videoQualityOptions = ["480p", "720p", "1080p", "4K"]

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

                    // Photo Settings
                    if settings.captureMode == .photo {
                        settingsSection(title: "Photo") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mégapixels")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.6))

                                HStack(spacing: 0) {
                                    ForEach(megapixelOptions, id: \.self) { mp in
                                        Button(action: {
                                            photoMegapixels = mp
                                            cameraManager.refreshConfiguration()
                                        }) {
                                            Text("\(mp) MP")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(photoMegapixels == mp ? .black : .white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(photoMegapixels == mp
                                                              ? Color.white
                                                              : Color.white.opacity(0.08))
                                                )
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Video Settings
                    if settings.captureMode == .video {
                        settingsSection(title: "Vidéo") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Qualité")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.6))

                                HStack(spacing: 0) {
                                    ForEach(videoQualityOptions, id: \.self) { quality in
                                        Button(action: {
                                            videoQuality = quality
                                            cameraManager.refreshConfiguration()
                                        }) {
                                            Text(quality)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(videoQuality == quality ? .black : .white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(videoQuality == quality
                                                              ? Color.white
                                                              : Color.white.opacity(0.08))
                                                )
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
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
