import Foundation
import UIKit
import AVFoundation

class GalleryStore: ObservableObject {
    @Published var items: [MediaItem] = []

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.nano.gallerystore", qos: .userInitiated)
    private var galleryURL: URL
    private var thumbnailsURL: URL
    private var indexURL: URL

    init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        galleryURL = docs.appendingPathComponent("NanoGallery", isDirectory: true)
        thumbnailsURL = galleryURL.appendingPathComponent("thumbnails", isDirectory: true)
        indexURL = galleryURL.appendingPathComponent("index.json")

        createDirectoriesIfNeeded()
        loadIndex()
    }

    // MARK: - Directory Setup

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: galleryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
    }

    // MARK: - Index Persistence

    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexURL.path) else { return }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([MediaItem].self, from: data)

            // Filter out items whose physical file no longer exists
            let validItems = loaded.filter { item in
                let path = galleryURL.appendingPathComponent(item.filename).path
                return fileManager.fileExists(atPath: path)
            }

            DispatchQueue.main.async {
                self.items = validItems.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            print("GalleryStore: Failed to load index: \(error)")
        }
    }

    private func saveIndex() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(items)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("GalleryStore: Failed to save index: \(error)")
        }
    }

    // MARK: - Save Photo

    func savePhoto(data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let id = UUID()
            let filename = "\(id.uuidString).heic"
            let fileURL = self.galleryURL.appendingPathComponent(filename)

            do {
                try data.write(to: fileURL, options: .atomic)

                // Generate thumbnail
                if let image = UIImage(data: data) {
                    self.generateThumbnail(image: image, for: id)
                }

                let attributes = try self.fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                let item = MediaItem(
                    id: id,
                    filename: filename,
                    type: .photo,
                    createdAt: Date(),
                    fileSize: fileSize
                )

                DispatchQueue.main.async {
                    self.items.insert(item, at: 0)
                    self.saveIndex()
                }
            } catch {
                print("GalleryStore: Failed to save photo: \(error)")
            }
        }
    }

    // MARK: - Save Video

    func saveVideo(url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let id = UUID()
            let filename = "\(id.uuidString).mov"
            let destURL = self.galleryURL.appendingPathComponent(filename)

            do {
                if self.fileManager.fileExists(atPath: destURL.path) {
                    try self.fileManager.removeItem(at: destURL)
                }
                try self.fileManager.copyItem(at: url, to: destURL)

                // Generate video thumbnail asynchronously after brief delay for file flush
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                    self.generateVideoThumbnail(url: destURL, for: id)
                }

                let attributes = try self.fileManager.attributesOfItem(atPath: destURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                let item = MediaItem(
                    id: id,
                    filename: filename,
                    type: .video,
                    createdAt: Date(),
                    fileSize: fileSize
                )

                DispatchQueue.main.async {
                    self.items.insert(item, at: 0)
                    self.saveIndex()
                }

                // Clean up temp file
                try? self.fileManager.removeItem(at: url)
            } catch {
                print("GalleryStore: Failed to save video: \(error)")
            }
        }
    }

    // MARK: - Thumbnails

    private func generateThumbnail(image: UIImage, for id: UUID) {
        let thumbSize = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: thumbSize)
        let thumb = renderer.image { _ in
            let aspectWidth = thumbSize.width / image.size.width
            let aspectHeight = thumbSize.height / image.size.height
            let aspectRatio = max(aspectWidth, aspectHeight)
            let scaledSize = CGSize(
                width: image.size.width * aspectRatio,
                height: image.size.height * aspectRatio
            )
            let origin = CGPoint(
                x: (thumbSize.width - scaledSize.width) / 2,
                y: (thumbSize.height - scaledSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }

        let thumbFilename = "thumb_\(id.uuidString).jpg"
        let thumbURL = thumbnailsURL.appendingPathComponent(thumbFilename)
        if let jpegData = thumb.jpegData(compressionQuality: 0.7) {
            try? jpegData.write(to: thumbURL, options: .atomic)
        }
    }

    private func generateVideoThumbnail(url: URL, for id: UUID) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            generateThumbnail(image: image, for: id)
        } catch {
            print("GalleryStore: Failed to generate video thumbnail: \(error)")
        }
    }

    // MARK: - Load Thumbnail

    func loadThumbnail(for item: MediaItem) -> UIImage? {
        let thumbURL = thumbnailsURL.appendingPathComponent(item.thumbnailFilename)
        guard let data = try? Data(contentsOf: thumbURL) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Full Path

    func getFullPath(for item: MediaItem) -> URL {
        galleryURL.appendingPathComponent(item.filename)
    }

    // MARK: - Delete

    func deleteItems(ids: Set<UUID>) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let toDelete = self.items.filter { ids.contains($0.id) }
            for item in toDelete {
                let fileURL = self.galleryURL.appendingPathComponent(item.filename)
                let thumbURL = self.thumbnailsURL.appendingPathComponent(item.thumbnailFilename)
                try? self.fileManager.removeItem(at: fileURL)
                try? self.fileManager.removeItem(at: thumbURL)
            }

            DispatchQueue.main.async {
                self.items.removeAll { ids.contains($0.id) }
                self.saveIndex()
            }
        }
    }

    // MARK: - Export

    func exportURLs(ids: Set<UUID>) -> [URL] {
        items
            .filter { ids.contains($0.id) }
            .map { getFullPath(for: $0) }
    }
}
