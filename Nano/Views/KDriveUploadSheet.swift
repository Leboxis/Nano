import SwiftUI

struct KDriveUploadSheet: View {
    let itemsToUpload: [MediaItem]
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var kDriveService = KDriveService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var targetDirectoryId: String = "1"
    @State private var targetDirectoryName: String = "Racine (kDrive)"
    @State private var showFolderPicker: Bool = false

    @State private var hasStarted: Bool = false
    @State private var uploadFinished: Bool = false
    @State private var successCount: Int = 0
    @State private var failedCount: Int = 0

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                        Text("Export kDrive")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: {
                        if kDriveService.isUploading {
                            kDriveService.cancelUpload()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Content Views according to current phase
                if !hasStarted && !uploadFinished {
                    preUploadConfigurationView
                } else if kDriveService.isUploading || (hasStarted && !uploadFinished) {
                    uploadingProgressView
                } else {
                    uploadFinishedSummaryView
                }
            }
        }
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showFolderPicker) {
            KDriveFolderPickerView(
                initialDirectoryId: targetDirectoryId,
                initialDirectoryName: targetDirectoryName,
                onSelect: { newId, newName in
                    targetDirectoryId = newId
                    targetDirectoryName = newName
                    // Also update default settings for next time
                    settings.kDriveDirectoryId = newId
                    settings.kDriveDirectoryName = newName
                }
            )
            .environmentObject(settings)
        }
        .onAppear {
            initializeTargetDirectory()
        }
    }

    // MARK: - Phase 1: Pre-Upload Configuration
    private var preUploadConfigurationView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 10)

            // Media Selection Summary
            VStack(spacing: 12) {
                HStack {
                    Text("\(itemsToUpload.count) élément\(itemsToUpload.count > 1 ? "s" : "") sélectionné\(itemsToUpload.count > 1 ? "s" : "")")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    let totalBytes = itemsToUpload.reduce(Int64(0)) { $0 + $1.fileSize }
                    Text(formatBytes(totalBytes))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }

                // Mini horizontal preview strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(itemsToUpload.prefix(8)) { item in
                            MiniThumbnailPreview(item: item, galleryStore: galleryStore)
                        }
                        if itemsToUpload.count > 8 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 56, height: 56)
                                Text("+\(itemsToUpload.count - 8)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            // Destination Folder Selector Card
            VStack(alignment: .leading, spacing: 8) {
                Text("DOSSIER DE DESTINATION")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.4))
                    .tracking(1.2)
                    .padding(.horizontal, 4)

                Button(action: {
                    showFolderPicker = true
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.18))
                                .frame(width: 44, height: 44)

                            Image(systemName: "folder.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(targetDirectoryName.isEmpty ? "Racine (kDrive)" : targetDirectoryName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text("ID du dossier : \(targetDirectoryId)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.4))
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Changer")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Bottom Start Upload Button
            Button(action: startUpload) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                    Text("Téléverser vers \"\(targetDirectoryName.isEmpty ? "Racine" : targetDirectoryName)\"")
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Phase 2: Uploading Progress
    private var uploadingProgressView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0.0, to: CGFloat(kDriveService.currentProgress))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90))
                    .frame(width: 110, height: 110)
                    .animation(.easeInOut(duration: 0.2), value: kDriveService.currentProgress)

                VStack(spacing: 2) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))

                    Text("\(Int(kDriveService.currentProgress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.9))
                }
            }

            VStack(spacing: 6) {
                Text("Envoi en cours...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text("Fichier \(kDriveService.currentFileIndex) sur \(max(1, kDriveService.totalFilesCount))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))

                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                    Text("Destination : \(targetDirectoryName)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.top, 2)

                if !kDriveService.currentFileName.isEmpty {
                    Text(kDriveService.currentFileName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 30)
                        .padding(.top, 4)
                }
            }

            Spacer()

            Button(action: {
                kDriveService.cancelUpload()
                dismiss()
            }) {
                Text("Annuler le transfert")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.red.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Phase 3: Finished Summary
    private var uploadFinishedSummaryView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(failedCount == 0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 88, height: 88)

                Image(systemName: failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 46))
                    .foregroundColor(failedCount == 0 ? .green : .orange)
            }

            Text(failedCount == 0 ? "Upload terminé avec succès" : "Upload terminé avec avertissements")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                Text("\(successCount) média\(successCount > 1 ? "s" : "") envoyé\(successCount > 1 ? "s" : "") dans \"\(targetDirectoryName)\"")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))

                if failedCount > 0 {
                    Text("\(failedCount) échec(s)")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                }

                if let err = kDriveService.lastError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(Color.red.opacity(0.9))
                        .padding(.top, 6)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("Terminer")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Actions & Helpers

    private func initializeTargetDirectory() {
        if !settings.kDriveDirectoryId.isEmpty {
            targetDirectoryId = settings.kDriveDirectoryId
        } else {
            targetDirectoryId = "1"
        }

        if !settings.kDriveDirectoryName.isEmpty {
            targetDirectoryName = settings.kDriveDirectoryName
        } else {
            targetDirectoryName = "Racine (kDrive)"
        }
    }

    private func startUpload() {
        guard !itemsToUpload.isEmpty else {
            uploadFinished = true
            return
        }

        hasStarted = true
        uploadFinished = false

        kDriveService.uploadBatch(
            items: itemsToUpload,
            galleryStore: galleryStore,
            settings: settings,
            targetDirectoryId: targetDirectoryId
        ) { success, failed, errorMsg in
            self.successCount = success
            self.failedCount = failed
            self.uploadFinished = true
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Mini Thumbnail Preview
struct MiniThumbnailPreview: View {
    let item: MediaItem
    let galleryStore: GalleryStore
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 56, height: 56)
            }

            if item.type == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Circle().fill(Color.black.opacity(0.6)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let img = galleryStore.loadThumbnail(for: item)
                DispatchQueue.main.async {
                    self.thumbnail = img
                }
            }
        }
    }
}
