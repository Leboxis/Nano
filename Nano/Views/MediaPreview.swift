import SwiftUI
import UIKit

// MARK: - Full Screen Media Pager (Swipe Left/Right between Gallery Items)

struct MediaPreviewPagerView: View {
    let initialIndex: Int
    @ObservedObject var galleryStore: GalleryStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0

    init(initialIndex: Int, galleryStore: GalleryStore) {
        self.initialIndex = initialIndex
        self.galleryStore = galleryStore
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !galleryStore.items.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(galleryStore.items.enumerated()), id: \.offset) { index, item in
                        SingleMediaPreviewView(
                            item: item,
                            isCurrent: index == currentIndex,
                            galleryStore: galleryStore
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            // Top Bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }

                    Spacer()

                    // Media counter: e.g. "3 / 12"
                    if currentIndex < galleryStore.items.count {
                        Text("\(currentIndex + 1) / \(galleryStore.items.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.7))
                    }

                    Spacer()

                    Button(action: shareCurrentItem) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()
            }
        }
        .statusBarHidden(true)
    }

    private func shareCurrentItem() {
        guard currentIndex >= 0 && currentIndex < galleryStore.items.count else { return }
        let item = galleryStore.items[currentIndex]
        let url = galleryStore.getFullPath(for: item)

        ShareSheetPresenter.present(items: [url])
    }
}

// MARK: - Single Media Item Preview (with Interactive Video Timeline Scrubber)

struct SingleMediaPreviewView: View {
    let item: MediaItem
    let isCurrent: Bool
    let galleryStore: GalleryStore

    @State private var displayImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if item.type == .photo {
                photoPreview
            } else {
                let url = galleryStore.getFullPath(for: item)
                InteractiveVideoPlayerView(url: url, isCurrent: isCurrent)
            }
        }
        .task(id: item.id) {
            guard item.type == .photo else { return }
            let image = await Task.detached(priority: .userInitiated) {
                galleryStore.loadDisplayImage(for: item)
            }.value
            displayImage = image
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let image = displayImage {
            ZoomableImageView(image: image)
        }
    }
}
