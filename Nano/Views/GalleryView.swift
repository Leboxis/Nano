import SwiftUI
import AVKit

struct GalleryView: View {
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings

    @State private var isSelecting = false
    @State private var selectedIds: Set<UUID> = []
    @State private var previewItem: MediaItem? = nil

    @State private var showKDriveUpload = false
    @State private var itemsToUpload: [MediaItem] = []
    @State private var showNotConfiguredAlert = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 56)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                if galleryStore.items.isEmpty {
                    emptyState
                } else {
                    // Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(galleryStore.items) { item in
                                ThumbnailCell(
                                    item: item,
                                    isSelecting: isSelecting,
                                    isSelected: selectedIds.contains(item.id),
                                    galleryStore: galleryStore
                                )
                                .onTapGesture {
                                    if isSelecting {
                                        toggleSelection(item.id)
                                    } else {
                                        previewItem = item
                                    }
                                }
                            }
                        }
                    }

                    // Selection toolbar
                    if isSelecting {
                        selectionToolbar
                    }
                }
            }
        }
        .fullScreenCover(item: $previewItem) { item in
            MediaPreviewView(item: item, galleryStore: galleryStore)
        }
        .sheet(isPresented: $showKDriveUpload) {
            KDriveUploadSheet(itemsToUpload: itemsToUpload)
                .environmentObject(galleryStore)
                .environmentObject(settings)
        }
        .alert("kDrive non configuré", isPresented: $showNotConfiguredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Veuillez renseigner votre Token API et ID de Drive dans les Réglages pour utiliser la synchronisation kDrive.")
        }
        .statusBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Text("Galerie")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if !galleryStore.items.isEmpty {
                if !isSelecting {
                    // Upload All to kDrive Button
                    Button(action: uploadAllToKDrive) {
                        HStack(spacing: 6) {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.system(size: 14))
                            Text("kDrive")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedIds.removeAll()
                        }
                    }
                }) {
                    Text(isSelecting ? "Annuler" : "Sélectionner")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isSelecting ? Color.red : Color.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(Color.white.opacity(0.2))
            Text("Aucun média")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.white.opacity(0.3))
            Text("Les photos et vidéos apparaîtront ici")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.15))
            Spacer()
        }
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 16) {
                // Select All
                Button(action: selectAll) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedIds.count == galleryStore.items.count
                              ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 20))
                        Text("Tout")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                }

                Spacer()

                // Count
                Text("\(selectedIds.count) sélectionné\(selectedIds.count > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))

                Spacer()

                // Upload selected to kDrive
                Button(action: uploadSelectedToKDrive) {
                    VStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 20))
                        Text("kDrive")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(selectedIds.isEmpty ? Color.white.opacity(0.3) : .white)
                }
                .disabled(selectedIds.isEmpty)

                // Export
                Button(action: exportSelected) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                        Text("Partager")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(selectedIds.isEmpty ? Color.white.opacity(0.3) : .white)
                }
                .disabled(selectedIds.isEmpty)

                // Delete
                Button(action: deleteSelected) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                        Text("Supprimer")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(selectedIds.isEmpty ? Color.red.opacity(0.3) : .red)
                }
                .disabled(selectedIds.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        }
    }

    // MARK: - Actions

    private func uploadAllToKDrive() {
        guard settings.isKDriveConfigured else {
            showNotConfiguredAlert = true
            return
        }
        itemsToUpload = galleryStore.items
        showKDriveUpload = true
    }

    private func uploadSelectedToKDrive() {
        guard settings.isKDriveConfigured else {
            showNotConfiguredAlert = true
            return
        }
        itemsToUpload = galleryStore.items.filter { selectedIds.contains($0.id) }
        showKDriveUpload = true
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func selectAll() {
        if selectedIds.count == galleryStore.items.count {
            selectedIds.removeAll()
        } else {
            selectedIds = Set(galleryStore.items.map { $0.id })
        }
    }

    private func exportSelected() {
        let urls = galleryStore.exportURLs(ids: selectedIds)
        guard !urls.isEmpty else { return }

        let activityVC = UIActivityViewController(
            activityItems: urls,
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }

    private func deleteSelected() {
        galleryStore.deleteItems(ids: selectedIds)
        selectedIds.removeAll()
        if galleryStore.items.isEmpty {
            isSelecting = false
        }
    }
}

// MARK: - Thumbnail Cell

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
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: geo.size.width, height: geo.size.width)
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

// MARK: - Media Preview

struct MediaPreviewView: View {
    let item: MediaItem
    let galleryStore: GalleryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if item.type == .photo {
                photoPreview
            } else {
                videoPreview
            }

            // Top bar
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }

                    Spacer()

                    Button(action: shareItem) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()
            }
        }
        .statusBarHidden(true)
    }

    @ViewBuilder
    private var photoPreview: some View {
        let url = galleryStore.getFullPath(for: item)
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            ZoomableImageView(image: image)
        }
    }

    @ViewBuilder
    private var videoPreview: some View {
        let url = galleryStore.getFullPath(for: item)
        VideoPlayer(player: AVPlayer(url: url))
            .ignoresSafeArea()
    }

    private func shareItem() {
        let url = galleryStore.getFullPath(for: item)

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Zoomable Image

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100
        scrollView.addSubview(imageView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }
    }
}
