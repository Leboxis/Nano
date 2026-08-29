import Foundation
import UIKit
import AVFoundation
import ImageIO

class GalleryStore: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var saveErrorMessage: String?

    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.nano.gallerystore", qos: .userInitiated)
    private var galleryURL: URL
    private var thumbnailsURL: URL

    private let thumbnailCache = NSCache<NSUUID, UIImage>()
    private let displayImageCache = NSCache<NSUUID, UIImage>()

    init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        galleryURL = docs.appendingPathComponent("NanoGallery", isDirectory: true)
        thumbnailsURL = galleryURL.appendingPathComponent("thumbnails", isDirectory: true)

        createDirectoriesIfNeeded()
        try? fileManager.removeItem(at: galleryURL.appendingPathComponent("index.json"))
        refresh()
    }

    // MARK: - Directory Setup

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: galleryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
    }

    // MARK: - Disk Scan (single source of truth)

    func refresh() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let scanned = self.scanDisk()
            DispatchQueue.main.async {
                self.items = scanned
            }
        }
    }

    private func scanDisk() -> [MediaItem] {
        let contents = (try? fileManager.contentsOfDirectory(
            at: galleryURL,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []

        var result: [MediaItem] = []
        for url in contents {
            let type: MediaType
            switch url.pathExtension.lowercased() {
            case "heic", "jpg", "jpeg", "png", "dng":
                type = .photo
            case "mov", "mp4":
                type = .video
            default:
                continue
            }

            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }

            let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            result.append(MediaItem(
                id: id,
                filename: url.lastPathComponent,
                type: type,
                createdAt: attrs?.creationDate ?? Date(),
                fileSize: Int64(attrs?.fileSize ?? 0)
            ))
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Save Photo

    func savePhoto(data: Data) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let id = UUID()
            let filename = "\(id.uuidString).heic"
            let fileURL = self.galleryURL.appendingPathComponent(filename)

            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("GalleryStore: Failed to save photo: \(error)")
                DispatchQueue.main.async {
                    self.reportError("Impossible d'enregistrer la photo")
                }
                return
            }

            if let thumb = self.downsampledImage(at: fileURL, maxPixelSize: 600) {
                self.writeThumbnail(thumb, for: id)
            }

            let item = self.makeItem(url: fileURL, id: id, filename: filename, type: .photo)

            DispatchQueue.main.async {
                self.insertSorted(item)
            }
        }
    }

    // MARK: - Save Video

    func saveVideo(url: URL) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let id = UUID()
            let filename = "\(id.uuidString).mov"
            let destURL = self.galleryURL.appendingPathComponent(filename)

            do {
                if self.fileManager.fileExists(atPath: destURL.path) {
                    try self.fileManager.removeItem(at: destURL)
                }
                try self.fileManager.copyItem(at: url, to: destURL)
                try? self.fileManager.removeItem(at: url)
            } catch {
                print("GalleryStore: Failed to save video: \(error)")
                DispatchQueue.main.async {
                    self.reportError("Impossible d'enregistrer la vidéo")
                }
                return
            }

            if let thumb = self.videoThumbnail(at: destURL) {
                self.writeThumbnail(thumb, for: id)
            }

            let item = self.makeItem(url: destURL, id: id, filename: filename, type: .video)

            DispatchQueue.main.async {
                self.insertSorted(item)
            }
        }
    }

    private func makeItem(url: URL, id: UUID, filename: String, type: MediaType) -> MediaItem {
        let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
        return MediaItem(
            id: id,
            filename: filename,
            type: type,
            createdAt: attrs?.creationDate ?? Date(),
            fileSize: Int64(attrs?.fileSize ?? 0)
        )
    }

    private func insertSorted(_ item: MediaItem) {
        items.append(item)
        items.sort { $0.createdAt > $1.createdAt }
    }

    private func reportError(_ message: String) {
        saveErrorMessage = message
    }

    // MARK: - Thumbnails

    private func downsampledImage(at url: URL, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func videoThumbnail(at url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        let times: [CMTime] = [
            CMTime(seconds: 0.5, preferredTimescale: 600),
            .zero
        ]

        for time in times {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                continue
            }
        }

        print("GalleryStore: Failed to generate video thumbnail: \(url.lastPathComponent)")
        return nil
    }

    private func writeThumbnail(_ image: UIImage, for id: UUID) {
        let thumbURL = thumbnailsURL.appendingPathComponent("thumb_\(id.uuidString).jpg")
        if let jpegData = image.jpegData(compressionQuality: 0.7) {
            try? jpegData.write(to: thumbURL, options: .atomic)
        }
    }

    // MARK: - Load Thumbnail

    func loadThumbnail(for item: MediaItem) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: item.id as NSUUID) {
            return cached
        }

        let thumbURL = thumbnailsURL.appendingPathComponent(item.thumbnailFilename)
        var image = UIImage(contentsOfFile: thumbURL.path)

        if image == nil {
            let sourceURL = galleryURL.appendingPathComponent(item.filename)
            image = item.type == .photo
                ? downsampledImage(at: sourceURL, maxPixelSize: 600)
                : videoThumbnail(at: sourceURL)
            if let regenerated = image {
                writeThumbnail(regenerated, for: item.id)
            }
        }

        guard let image = image else { return nil }
        thumbnailCache.setObject(image, forKey: item.id as NSUUID)
        return image
    }

    // MARK: - Full Screen Display Image (screen-resolution downsampling)

    func loadDisplayImage(for item: MediaItem) -> UIImage? {
        if let cached = displayImageCache.object(forKey: item.id as NSUUID) {
            return cached
        }

        let url = galleryURL.appendingPathComponent(item.filename)
        let maxPixelSize = UIScreen.main.scale > 2 ? 3600 : 2400
        guard let image = downsampledImage(at: url, maxPixelSize: maxPixelSize) else { return nil }

        displayImageCache.setObject(image, forKey: item.id as NSUUID)
        return image
    }

    // MARK: - Full Path

    func getFullPath(for item: MediaItem) -> URL {
        galleryURL.appendingPathComponent(item.filename)
    }

    // MARK: - Delete

    func deleteItems(ids: Set<UUID>) {
        let targets = items
            .filter { ids.contains($0.id) }
            .map { (id: $0.id, file: galleryURL.appendingPathComponent($0.filename), thumb: thumbnailsURL.appendingPathComponent($0.thumbnailFilename)) }

        ioQueue.async { [weak self] in
            guard let self = self else { return }
            for target in targets {
                try? self.fileManager.removeItem(at: target.file)
                try? self.fileManager.removeItem(at: target.thumb)
                self.thumbnailCache.removeObject(forKey: target.id as NSUUID)
                self.displayImageCache.removeObject(forKey: target.id as NSUUID)
            }

            DispatchQueue.main.async {
                self.items.removeAll { ids.contains($0.id) }
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
