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
    @AppStorage("photoMegapixels") var photoMegapixels: Int = 12
    @AppStorage("videoQuality") var videoQuality: String = "1080p"

    // MARK: - Infomaniak kDrive Settings
    @AppStorage("kDriveApiToken") var kDriveApiToken: String = ""
    @AppStorage("kDriveId") var kDriveId: String = ""
    @AppStorage("kDriveDirectoryId") var kDriveDirectoryId: String = "1"
    @AppStorage("kDriveDirectoryName") var kDriveDirectoryName: String = "Racine (kDrive)"

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
