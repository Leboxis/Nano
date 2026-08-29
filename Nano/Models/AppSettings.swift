import Foundation
import SwiftUI

enum CaptureMode: String, CaseIterable {
    case photo = "photo"
    case video = "video"

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Vidéo"
        }
    }
}

class AppSettings: ObservableObject {
    @AppStorage("lastMode") var lastMode: String = "photo"
    @AppStorage("photoMegapixels") var photoMegapixels: Int = 24
    @AppStorage("videoQuality") var videoQuality: String = "4K"
    @AppStorage("videoFPS") var videoFPS: Int = 60
    @AppStorage("zoomLevel") var zoomLevel: Int = 1
    @AppStorage("vibrationsEnabled") var vibrationsEnabled: Bool = true
    @AppStorage("useFrontCamera") var useFrontCamera: Bool = false

    // MARK: - Infomaniak kDrive Settings
    @AppStorage("kDriveApiToken") var kDriveApiToken: String = ""
    @AppStorage("kDriveId") var kDriveId: String = ""
    @AppStorage("kDriveDirectoryId") var kDriveDirectoryId: String = "1"
    @AppStorage("kDriveDirectoryName") var kDriveDirectoryName: String = "Racine (kDrive)"
    @AppStorage("deleteAfterUpload") var deleteAfterUpload: Bool = false

    var isKDriveConfigured: Bool {
        !kDriveApiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !kDriveId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var captureMode: CaptureMode {
        get { CaptureMode(rawValue: lastMode) ?? .photo }
        set {
            lastMode = newValue.rawValue
            objectWillChange.send()
        }
    }
}
