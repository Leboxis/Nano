import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cameraManager: CameraManager

    @AppStorage("photoMegapixels") private var photoMegapixels: Int = 12
    @AppStorage("videoQuality") private var videoQuality: String = "1080p"

    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus? = nil
    @State private var showToken = false
    @State private var showFolderPicker = false

    private let megapixelOptions = [8, 12, 24, 48]
    private let videoQualityOptions = ["480p", "720p", "1080p", "4K"]

    enum ConnectionStatus {
        case success(String)
        case error(String)
    }

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

                    // Infomaniak kDrive Section
                    settingsSection(title: "Infomaniak kDrive") {
                        VStack(alignment: .leading, spacing: 16) {
                            // API Token
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Token API")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.6))
                                    Spacer()
                                    Button(action: { showToken.toggle() }) {
                                        Image(systemName: showToken ? "eye.slash" : "eye")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.4))
                                    }
                                    Button(action: pasteToken) {
                                        Text("Coller")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.leading, 8)
                                }

                                if showToken {
                                    TextField("Bearer token...", text: $settings.kDriveApiToken)
                                        .textFieldStyle(CustomDarkTextFieldStyle())
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("Bearer token...", text: $settings.kDriveApiToken)
                                        .textFieldStyle(CustomDarkTextFieldStyle())
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                            }

                            // Drive ID
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ID du Drive (kDrive ID)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.6))

                                TextField("Ex: 123456", text: $settings.kDriveId)
                                    .textFieldStyle(CustomDarkTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }

                            // Directory / Folder Selection
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Dossier de destination")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.6))

                                Button(action: {
                                    showFolderPicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                                        Text(settings.kDriveDirectoryName.isEmpty ? "Racine (kDrive)" : settings.kDriveDirectoryName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("ID: \(settings.kDriveDirectoryId)")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(Color.white.opacity(0.35))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.3))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .disabled(!settings.isKDriveConfigured)
                                .opacity(settings.isKDriveConfigured ? 1.0 : 0.4)
                            }

                            // Test Connection Button
                            Button(action: testConnection) {
                                HStack(spacing: 8) {
                                    if isTestingConnection {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "network")
                                            .font(.system(size: 14))
                                    }
                                    Text("Tester la connexion")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .disabled(isTestingConnection || !settings.isKDriveConfigured)
                            .opacity(settings.isKDriveConfigured ? 1.0 : 0.4)

                            // Status Banner
                            if let status = connectionStatus {
                                HStack(spacing: 8) {
                                    switch status {
                                    case .success(let driveName):
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Connecté : \(driveName)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.green)
                                    case .error(let message):
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(message)
                                            .font(.system(size: 12))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.top, 4)
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
        .sheet(isPresented: $showFolderPicker) {
            KDriveFolderPickerView()
                .environmentObject(settings)
        }
        .statusBarHidden(true)
    }

    // MARK: - Actions
    private func pasteToken() {
        if let clip = UIPasteboard.general.string {
            settings.kDriveApiToken = clip.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionStatus = nil

        Task {
            do {
                let name = try await KDriveService.shared.testConnection(
                    token: settings.kDriveApiToken,
                    driveId: settings.kDriveId
                )
                await MainActor.run {
                    self.connectionStatus = .success(name)
                    self.isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = .error(error.localizedDescription)
                    self.isTestingConnection = false
                }
            }
        }
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

// Custom Dark Text Field Style
struct CustomDarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .foregroundColor(.white)
            .font(.system(size: 14, design: .monospaced))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
