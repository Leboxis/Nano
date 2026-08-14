import SwiftUI

struct KDriveUploadSheet: View {
    let itemsToUpload: [MediaItem]
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var kDriveService = KDriveService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var uploadFinished = false
    @State private var successCount = 0
    @State private var failedCount = 0
    @State private var statusMessage: String = "Préparation de l'envoi..."

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header Bar
                HStack {
                    Text("Infomaniak kDrive")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        if kDriveService.isUploading {
                            kDriveService.cancelUpload()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)

                Spacer()

                // Center Content
                VStack(spacing: 20) {
                    if uploadFinished {
                        // Finished State
                        ZStack {
                            Circle()
                                .fill(failedCount == 0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .frame(width: 90, height: 90)

                            Image(systemName: failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(failedCount == 0 ? .green : .orange)
                        }

                        Text(failedCount == 0 ? "Upload terminé avec succès" : "Upload terminé avec avertissements")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 6) {
                            Text("\(successCount) média\(successCount > 1 ? "s" : "") envoyé\(successCount > 1 ? "s" : "") vers kDrive")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.7))

                            if failedCount > 0 {
                                Text("\(failedCount) échec(s)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                            }

                            if let err = kDriveService.lastError {
                                Text(err)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.red.opacity(0.8))
                                    .padding(.top, 4)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    } else {
                        // Uploading State
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 6)
                                .frame(width: 100, height: 100)

                            Circle()
                                .trim(from: 0.0, to: CGFloat(kDriveService.currentProgress))
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(Angle(degrees: -90))
                                .frame(width: 100, height: 100)
                                .animation(.easeInOut(duration: 0.2), value: kDriveService.currentProgress)

                            VStack(spacing: 2) {
                                Image(systemName: "icloud.and.arrow.up.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)

                                Text("\(Int(kDriveService.currentProgress * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.8))
                            }
                        }

                        VStack(spacing: 6) {
                            Text("Envoi en cours...")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Fichier \(kDriveService.currentFileIndex) sur \(max(1, kDriveService.totalFilesCount))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))

                            if !kDriveService.currentFileName.isEmpty {
                                Text(kDriveService.currentFileName)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.35))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                }

                Spacer()

                // Bottom Action
                if uploadFinished {
                    Button(action: { dismiss() }) {
                        Text("Fermer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                } else {
                    Button(action: {
                        kDriveService.cancelUpload()
                        dismiss()
                    }) {
                        Text("Annuler")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
        .onAppear {
            startUpload()
        }
    }

    private func startUpload() {
        guard !itemsToUpload.isEmpty else {
            uploadFinished = true
            return
        }

        kDriveService.uploadBatch(
            items: itemsToUpload,
            galleryStore: galleryStore,
            settings: settings
        ) { success, failed, errorMsg in
            self.successCount = success
            self.failedCount = failed
            self.uploadFinished = true
        }
    }
}
