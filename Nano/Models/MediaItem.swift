import Foundation

enum MediaType: String, Codable {
    case photo
    case video
}

struct MediaItem: Identifiable, Codable, Equatable {
    let id: UUID
    let filename: String
    let type: MediaType
    let createdAt: Date
    let fileSize: Int64

    var thumbnailFilename: String {
        "thumb_\(id.uuidString).jpg"
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}
