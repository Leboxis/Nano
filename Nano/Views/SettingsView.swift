import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cameraManager: CameraManager

    @AppStorage("photoMegapixels") private var photoMegapixels: Int = 24
    @AppStorage("videoQuality") private var videoQuality: String = "4K"
    @AppStorage("videoFPS") private var videoFPS: Int = 60
    @AppStorage("burstQualityMode") private var burstQualityMode: String = "balanced"

    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus? = nil
    @State private var showToken = false
    @State private var showFolderPicker = false

    private let videoQualityOptions = ["480p", "720p", "1080p", "4K"]
    private let fpsOptions = [30, 60]
    private let zoomOptions = [1, 2, 3]

    private var megapixelOptions: [Int] {
        settings.useFrontCamera ? [12] : [24, 48]
    }

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
                                            normalizeMegapixels()
                                            cameraManager.switchCamera(toFront: false)
                                        }
                                    )
                                    optionButton(
                                        label: "Avant",
                                        isSelected: settings.useFrontCamera,
                                        action: {
                                            settings.useFrontCamera = true
                                            normalizeMegapixels()
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
                            VStack(alignment: .leading, spacing: 20) {
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

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Rafale (appui long)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.6))

                                    HStack(spacing: 0) {
                                        optionButton(
                                            label: "Équilibrée",
                                            isSelected: burstQualityMode == "balanced",
                                            action: { burstQualityMode = "balanced" }
                                        )
                                        optionButton(
                                            label: "Rapide",
                                            isSelected: burstQualityMode == "speed",
                                            action: { burstQualityMode = "speed" }
                                        )
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Text("Équilibrée privilégie la qualité d'image, rapide privilégie le nombre de photos par seconde.")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.35))
                                }
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

                                // Stabilization
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle(isOn: $settings.videoStabilization) {
                                        HStack {
                                            Image(systemName: "video.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color.white.opacity(0.6))
                                                .frame(width: 20)
                                            Text("Stabilisation")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .tint(Color.white)
                                    .onChange(of: settings.videoStabilization) { enabled in
                                        cameraManager.updateVideoStabilization(enabled)
                                    }

                                    Text("Compense les mouvements avec un léger recadrage numérique. Caméra arrière uniquement.")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.white.opacity(0.35))
                                }
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

                            // Delete after upload
                            Toggle(isOn: $settings.deleteAfterUpload) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.6))
                                        .frame(width: 20)
                                    Text("Supprimer localement après l'envoi")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .tint(Color.white)

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
                            infoRow(label: "Version", value: appVersion)
                            infoRow(label: "Build", value: appBuild)
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
        .onAppear {
            normalizeMegapixels()
        }
        .onChange(of: settings.useFrontCamera) { _ in
            normalizeMegapixels()
        }
        .statusBarHidden(true)
    }

    // MARK: - Actions

    private func normalizeMegapixels() {
        let valid: [Int] = settings.useFrontCamera ? [12] : [24, 48]
        if !valid.contains(photoMegapixels) {
            let fallback = settings.useFrontCamera ? 12 : 24
            photoMegapixels = fallback
            cameraManager.updateMegapixels(fallback)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

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
