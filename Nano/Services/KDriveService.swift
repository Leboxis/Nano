import Foundation

enum KDriveError: LocalizedError {
    case invalidConfiguration
    case invalidURL
    case authenticationFailed
    case driveNotFound
    case uploadFailed(String)
    case serverError(Int, String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Veuillez configurer votre Token API et ID de Drive dans les Réglages."
        case .invalidURL:
            return "URL de requête kDrive invalide."
        case .authenticationFailed:
            return "Échec d'authentification : vérifiez votre Token API Infomaniak."
        case .driveNotFound:
            return "Drive introuvable : vérifiez l'ID de votre kDrive."
        case .uploadFailed(let reason):
            return "Échec de l'envoi : \(reason)"
        case .serverError(let code, let msg):
            return "Erreur serveur (\(code)) : \(msg)"
        case .cancelled:
            return "Upload annulé par l'utilisateur."
        }
    }
}

struct KDriveDriveInfo: Codable {
    let id: Int
    let name: String
}

struct KDriveAPIResponse<T: Codable>: Codable {
    let result: String
    let data: T?
    let error: KDriveAPIError?
}

struct KDriveAPIError: Codable {
    let code: String?
    let description: String?
}

@MainActor
class KDriveService: ObservableObject {
    static let shared = KDriveService()

    @Published var isUploading: Bool = false
    @Published var currentProgress: Double = 0.0
    @Published var currentFileIndex: Int = 0
    @Published var totalFilesCount: Int = 0
    @Published var currentFileName: String = ""
    @Published var lastError: String? = nil

    private var activeTask: Task<Void, Never>? = nil

    // MARK: - Validate Connection
    func testConnection(token: String, driveId: String) async throws -> String {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDriveId = driveId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty, !cleanDriveId.isEmpty else {
            throw KDriveError.invalidConfiguration
        }

        guard let url = URL(string: "https://api.infomaniak.com/2/drive/\(cleanDriveId)") else {
            throw KDriveError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KDriveError.serverError(0, "Réponse réseau inattendue")
        }

        if httpResponse.statusCode == 401 {
            throw KDriveError.authenticationFailed
        } else if httpResponse.statusCode == 404 {
            throw KDriveError.driveNotFound
        } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            if let decoded = try? JSONDecoder().decode(KDriveAPIResponse<KDriveDriveInfo>.self, from: data),
               let desc = decoded.error?.description {
                throw KDriveError.serverError(httpResponse.statusCode, desc)
            }
            throw KDriveError.serverError(httpResponse.statusCode, "Erreur HTTP \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(KDriveAPIResponse<KDriveDriveInfo>.self, from: data)
        if let drive = decoded.data {
            return drive.name
        } else {
            return "kDrive (ID: \(cleanDriveId))"
        }
    }

    // MARK: - Upload Single File
    func uploadFile(
        fileURL: URL,
        fileName: String,
        fileSize: Int64,
        token: String,
        driveId: String,
        directoryId: String
    ) async throws {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDriveId = driveId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDirId = directoryId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1" : directoryId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty, !cleanDriveId.isEmpty else {
            throw KDriveError.invalidConfiguration
        }

        var components = URLComponents(string: "https://api.infomaniak.com/3/drive/\(cleanDriveId)/upload")
        components?.queryItems = [
            URLQueryItem(name: "directory_id", value: cleanDirId),
            URLQueryItem(name: "file_name", value: fileName),
            URLQueryItem(name: "total_size", value: String(fileSize)),
            URLQueryItem(name: "conflict", value: "version")
        ]

        guard let requestURL = components?.url else {
            throw KDriveError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KDriveError.serverError(0, "Réponse inattendue du serveur")
        }

        if httpResponse.statusCode == 401 {
            throw KDriveError.authenticationFailed
        } else if httpResponse.statusCode == 404 {
            throw KDriveError.uploadFailed("Dossier ou Drive introuvable (code 404)")
        } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let desc = errorObj["description"] as? String {
                throw KDriveError.serverError(httpResponse.statusCode, desc)
            }
            throw KDriveError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }
    }

    // MARK: - Batch Upload
    func uploadBatch(
        items: [MediaItem],
        galleryStore: GalleryStore,
        settings: AppSettings,
        completion: @escaping (_ successCount: Int, _ failedCount: Int, _ errorMessage: String?) -> Void
    ) {
        guard settings.isKDriveConfigured else {
            completion(0, items.count, KDriveError.invalidConfiguration.localizedDescription)
            return
        }

        cancelUpload()

        isUploading = true
        currentProgress = 0.0
        currentFileIndex = 0
        totalFilesCount = items.count
        currentFileName = ""
        lastError = nil

        activeTask = Task {
            var success = 0
            var failed = 0
            var lastErrorMessage: String? = nil

            for (index, item) in items.enumerated() {
                if Task.isCancelled {
                    break
                }

                self.currentFileIndex = index + 1
                self.currentFileName = item.filename
                self.currentProgress = Double(index) / Double(max(1, items.count))

                let fileURL = galleryStore.getFullPath(for: item)

                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    failed += 1
                    continue
                }

                do {
                    try await uploadFile(
                        fileURL: fileURL,
                        fileName: item.filename,
                        fileSize: item.fileSize,
                        token: settings.kDriveApiToken,
                        driveId: settings.kDriveId,
                        directoryId: settings.kDriveDirectoryId
                    )
                    success += 1
                } catch {
                    failed += 1
                    lastErrorMessage = error.localizedDescription
                    print("KDrive upload error for \(item.filename): \(error)")
                }
            }

            self.currentProgress = 1.0
            self.isUploading = false

            if Task.isCancelled {
                completion(success, failed, "Upload annulé.")
            } else {
                completion(success, failed, lastErrorMessage)
            }
        }
    }

    func cancelUpload() {
        activeTask?.cancel()
        activeTask = nil
        isUploading = false
    }
}
