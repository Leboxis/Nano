import SwiftUI
import UIKit

struct ThumbnailCell: View {
    let item: MediaItem
    let isSelecting: Bool
    let isSelected: Bool
    let galleryStore: GalleryStore

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail image
            GeometryReader { geo in
                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: geo.size.width, height: geo.size.width)

                        Image(systemName: item.type == .video ? "video.fill" : "photo.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.white.opacity(0.2))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Video icon
            if item.type == .video {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                            )
                            .padding(6)
                        Spacer()
                    }
                }
            }

            // Selection checkmark
            if isSelecting {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color.black.opacity(0.4))
                        .frame(width: 24, height: 24)

                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .padding(6)
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: item.id) { _ in
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = galleryStore.loadThumbnail(for: item)
            DispatchQueue.main.async {
                thumbnail = img
            }
        }
    }
}
