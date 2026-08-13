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

    var captureMode: CaptureMode {
        get { CaptureMode(rawValue: lastMode) ?? .photo }
        set {
            lastMode = newValue.rawValue
            objectWillChange.send()
        }
    }
}
