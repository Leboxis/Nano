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

    // MARK: - Index Persistence & Sync

    private func loadIndex() {
        createDirectoriesIfNeeded()
        syncWithDisk()
    }

    func syncWithDisk() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.createDirectoriesIfNeeded()

            var diskItems: [MediaItem] = []
            var knownIds = Set<UUID>()

            // 1. Try reading existing index.json
            if self.fileManager.fileExists(atPath: self.indexURL.path) {
                if let data = try? Data(contentsOf: self.indexURL) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    if let loaded = try? decoder.decode([MediaItem].self, from: data) {
                        for item in loaded {
                            let path = self.galleryURL.appendingPathComponent(item.filename).path
                            if self.fileManager.fileExists(atPath: path) {
                                diskItems.append(item)
                                knownIds.insert(item.id)
                            }
                        }
                    }
                }
            }

            // 2. Scan physical directory to discover any unindexed files
            if let fileURLs = try? self.fileManager.contentsOfDirectory(
                at: self.galleryURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in fileURLs {
                    let filename = url.lastPathComponent
                    if filename == "thumbnails" || filename == "index.json" { continue }

                    let ext = url.pathExtension.lowercased()
                    guard ext == "heic" || ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "mov" || ext == "mp4" else {
                        continue
                    }

                    let nameWithoutExt = url.deletingPathExtension().lastPathComponent
                    let parsedUUID = UUID(uuidString: nameWithoutExt) ?? UUID()

                    if !knownIds.contains(parsedUUID) {
                        let isVideo = (ext == "mov" || ext == "mp4")
                        let attr = (try? self.fileManager.attributesOfItem(atPath: url.path)) ?? [:]
                        let size = attr[.size] as? Int64 ?? 0
                        let date = (attr[.creationDate] as? Date) ?? (attr[.modificationDate] as? Date) ?? Date()

                        let newItem = MediaItem(
                            id: parsedUUID,
                            filename: filename,
                            type: isVideo ? .video : .photo,
                            createdAt: date,
                            fileSize: size
                        )

                        diskItems.append(newItem)
                        knownIds.insert(parsedUUID)

                        // Generate missing thumbnail
                        if !isVideo {
                            if let imgData = try? Data(contentsOf: url), let img = UIImage(data: imgData) {
                                self.generateThumbnail(image: img, for: parsedUUID)
                            }
                        } else {
                            self.generateVideoThumbnail(url: url, for: parsedUUID)
                        }
                    }
                }
            }

            // Sort by newest first
            diskItems.sort { $0.createdAt > $1.createdAt }

            DispatchQueue.main.async {
                self.items = diskItems
                self.saveIndex()
            }
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

            self.createDirectoriesIfNeeded()

            let id = UUID()
            let filename = "\(id.uuidString).heic"
            let fileURL = self.galleryURL.appendingPathComponent(filename)

            do {
                try data.write(to: fileURL, options: .atomic)

                // Generate thumbnail immediately
                if let image = UIImage(data: data) {
                    self.generateThumbnail(image: image, for: id)
                }

                let attributes = (try? self.fileManager.attributesOfItem(atPath: fileURL.path)) ?? [:]
                let fileSize = attributes[.size] as? Int64 ?? Int64(data.count)

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
                    print("GalleryStore: Photo successfully added to gallery (\(filename), \(fileSize) bytes). Total items: \(self.items.count)")
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

            self.createDirectoriesIfNeeded()

            let id = UUID()
            let filename = "\(id.uuidString).mov"
            let destURL = self.galleryURL.appendingPathComponent(filename)

            do {
                if self.fileManager.fileExists(atPath: destURL.path) {
                    try self.fileManager.removeItem(at: destURL)
                }
                try self.fileManager.copyItem(at: url, to: destURL)

                // Generate video thumbnail asynchronously
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                    self.generateVideoThumbnail(url: destURL, for: id)
                }

                let attributes = (try? self.fileManager.attributesOfItem(atPath: destURL.path)) ?? [:]
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
                    print("GalleryStore: Video successfully added to gallery (\(filename)). Total items: \(self.items.count)")
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
            let aspectWidth = thumbSize.width / max(1, image.size.width)
            let aspectHeight = thumbSize.height / max(1, image.size.height)
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

    // MARK: - Load Thumbnail with Fallback

    func loadThumbnail(for item: MediaItem) -> UIImage? {
        let thumbURL = thumbnailsURL.appendingPathComponent(item.thumbnailFilename)
        if let data = try? Data(contentsOf: thumbURL), let img = UIImage(data: data) {
            return img
        }

        // Fallback: If thumbnail doesn't exist yet, load from full file and generate thumb
        let fullURL = getFullPath(for: item)
        if item.type == .photo {
            if let data = try? Data(contentsOf: fullURL), let img = UIImage(data: data) {
                queue.async {
                    self.generateThumbnail(image: img, for: item.id)
                }
                return img
            }
        } else if item.type == .video {
            queue.async {
                self.generateVideoThumbnail(url: fullURL, for: item.id)
            }
        }
        return nil
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
