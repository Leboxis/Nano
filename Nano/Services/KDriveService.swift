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

struct KDriveFolderItem: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let name: String
    let type: String? // "dir" or "file"

    var isDirectory: Bool {
        type == "dir" || type == "directory" || type == nil
    }
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

    // MARK: - Fetch Subdirectories
    func fetchSubdirectories(
        token: String,
        driveId: String,
        directoryId: String = "1"
    ) async throws -> [KDriveFolderItem] {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDriveId = driveId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDirId = directoryId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1" : directoryId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty, !cleanDriveId.isEmpty else {
            throw KDriveError.invalidConfiguration
        }

        guard let url = URL(string: "https://api.infomaniak.com/3/drive/\(cleanDriveId)/files/\(cleanDirId)/files?limit=500") else {
            throw KDriveError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KDriveError.serverError(0, "Réponse inattendue du serveur")
        }

        if httpResponse.statusCode == 401 {
            throw KDriveError.authenticationFailed
        } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            if let decoded = try? JSONDecoder().decode(KDriveAPIResponse<[KDriveFolderItem]>.self, from: data),
               let desc = decoded.error?.description {
                throw KDriveError.serverError(httpResponse.statusCode, desc)
            }
            throw KDriveError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }

        let decoded = try JSONDecoder().decode(KDriveAPIResponse<[KDriveFolderItem]>.self, from: data)
        let folders = (decoded.data ?? []).filter { $0.isDirectory }
        return folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Create Directory
    func createDirectory(
        token: String,
        driveId: String,
        parentDirectoryId: String = "1",
        folderName: String
    ) async throws -> KDriveFolderItem {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDriveId = driveId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanParentId = parentDirectoryId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1" : parentDirectoryId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty, !cleanDriveId.isEmpty, !cleanName.isEmpty else {
            throw KDriveError.invalidConfiguration
        }

        guard let url = URL(string: "https://api.infomaniak.com/3/drive/\(cleanDriveId)/files/\(cleanParentId)/directory") else {
            throw KDriveError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let bodyPayload = ["name": cleanName]
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KDriveError.serverError(0, "Réponse inattendue du serveur")
        }

        if httpResponse.statusCode == 401 {
            throw KDriveError.authenticationFailed
        } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            if let decoded = try? JSONDecoder().decode(KDriveAPIResponse<KDriveFolderItem>.self, from: data),
               let desc = decoded.error?.description {
                throw KDriveError.serverError(httpResponse.statusCode, desc)
            }
            throw KDriveError.serverError(httpResponse.statusCode, "Erreur création dossier (\(httpResponse.statusCode))")
        }

        let decoded = try JSONDecoder().decode(KDriveAPIResponse<KDriveFolderItem>.self, from: data)
        guard let folder = decoded.data else {
            throw KDriveError.serverError(httpResponse.statusCode, "Impossible de lire le dossier créé")
        }

        return folder
    }

    // MARK: - Upload Single File

    private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
        let onProgress: (Int64, Int64) -> Void

        init(onProgress: @escaping (Int64, Int64) -> Void) {
            self.onProgress = onProgress
        }

        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        didSendBodyData bytesSent: Int64,
                        totalBytesSent: Int64,
                        totalBytesExpectedToSend: Int64) {
            onProgress(totalBytesSent, max(1, totalBytesExpectedToSend))
        }
    }

    func uploadFile(
        fileURL: URL,
        fileName: String,
        fileSize: Int64,
        token: String,
        driveId: String,
        directoryId: String,
        progressHandler: ((Double) -> Void)? = nil
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

        let delegate = UploadProgressDelegate { sent, total in
            progressHandler?(Double(sent) / Double(total))
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.upload(for: request, fromFile: fileURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KDriveError.serverError(0, "Réponse inattendue du serveur")
        }

        if httpResponse.statusCode == 401 {
            throw KDriveError.authenticationFailed
        } else if httpResponse.statusCode == 404 {
            throw KDriveError.uploadFailed("Dossier (ID: \(cleanDirId)) ou Drive introuvable (code 404). Veuillez choisir un dossier existant.")
        } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let desc = errorObj["description"] as? String {
                throw KDriveError.serverError(httpResponse.statusCode, desc)
            }
            throw KDriveError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }
    }

    private func uploadWithRetry(
        fileURL: URL,
        fileName: String,
        fileSize: Int64,
        token: String,
        driveId: String,
        directoryId: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let maxAttempts = 2

        for attempt in 1...maxAttempts {
            do {
                try await uploadFile(
                    fileURL: fileURL,
                    fileName: fileName,
                    fileSize: fileSize,
                    token: token,
                    driveId: driveId,
                    directoryId: directoryId,
                    progressHandler: progressHandler
                )
                return
            } catch let error as KDriveError {
                switch error {
                case .invalidConfiguration, .invalidURL, .authenticationFailed, .driveNotFound, .cancelled:
                    throw error
                default:
                    if attempt == maxAttempts { throw error }
                }
            } catch {
                if attempt == maxAttempts { throw error }
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    // MARK: - Batch Upload

    func uploadBatch(
        items: [MediaItem],
        galleryStore: GalleryStore,
        settings: AppSettings,
        targetDirectoryId: String? = nil,
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

        let destDirectoryId: String
        if let customDir = targetDirectoryId?.trimmingCharacters(in: .whitespacesAndNewlines), !customDir.isEmpty {
            destDirectoryId = customDir
        } else {
            destDirectoryId = settings.kDriveDirectoryId
        }

        let token = settings.kDriveApiToken
        let driveId = settings.kDriveId
        let deleteAfterUpload = settings.deleteAfterUpload
        let fileURLs = Dictionary(uniqueKeysWithValues: items.map { ($0.id, galleryStore.getFullPath(for: $0)) })

        activeTask = Task {
            var success = 0
            var failed = 0
            var completed = 0
            var lastErrorMessage: String? = nil
            var uploadedIds: [UUID] = []
            var inFlightProgress: [UUID: Double] = [:]

            func reportGlobalProgress() {
                let inFlightSum = inFlightProgress.values.reduce(0.0, +)
                self.currentProgress = min(1.0, (Double(completed) + inFlightSum) / Double(max(1, items.count)))
            }

            func handleResult(item: MediaItem, result: Result<Void, Error>) {
                completed += 1
                inFlightProgress[item.id] = nil
                switch result {
                case .success:
                    success += 1
                    uploadedIds.append(item.id)
                case .failure(let error):
                    failed += 1
                    lastErrorMessage = error.localizedDescription
                    print("KDrive upload error for \(item.filename): \(error)")
                }
                self.currentFileIndex = completed
                self.currentFileName = item.filename
                reportGlobalProgress()
            }

            let chunks = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }

            for chunk in chunks {
                if Task.isCancelled { break }

                await withTaskGroup(of: (MediaItem, Result<Void, Error>).self) { group in
                    for item in chunk {
                        group.addTask {
                            let fileURL = fileURLs[item.id] ?? URL(fileURLWithPath: "/dev/null")

                            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                                return (item, .failure(KDriveError.uploadFailed("Fichier introuvable sur l'appareil")))
                            }

                            do {
                                try await uploadWithRetry(
                                    fileURL: fileURL,
                                    fileName: item.filename,
                                    fileSize: item.fileSize,
                                    token: token,
                                    driveId: driveId,
                                    directoryId: destDirectoryId,
                                    progressHandler: { fraction in
                                        DispatchQueue.main.async {
                                            inFlightProgress[item.id] = fraction
                                            reportGlobalProgress()
                                        }
                                    }
                                )
                                return (item, .success(()))
                            } catch {
                                return (item, .failure(error))
                            }
                        }
                    }

                    for await (item, result) in group {
                        handleResult(item: item, result: result)
                    }
                }
            }

            self.currentProgress = 1.0
            self.isUploading = false

            if deleteAfterUpload && !Task.isCancelled && !uploadedIds.isEmpty {
                galleryStore.deleteItems(ids: Set(uploadedIds))
            }

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
