import SwiftUI
import AVKit
import LocalAuthentication

struct ItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct GalleryView: View {
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var settings: AppSettings

    @Binding var selectedTab: Int
    @State private var isSelecting = false
    @State private var selectedIds: Set<UUID> = []
    @State private var previewIndex: Int? = nil
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var startRow: Int? = nil
    @State private var isUnlocked = false
    @State private var isAuthenticating = false

    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }

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

            if isUnlocked {
                unlockedContent
            } else {
                lockedState
            }
        }
        .fullScreenCover(item: Binding(
            get: {
                if let idx = previewIndex, idx >= 0 && idx < galleryStore.items.count {
                    return galleryStore.items[idx]
                }
                return nil
            },
            set: { newValue in
                if newValue == nil {
                    previewIndex = nil
                }
            }
        )) { _ in
            if let initialIdx = previewIndex {
                MediaPreviewPagerView(initialIndex: initialIdx, galleryStore: galleryStore)
            }
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
        .onAppear {
            triggerFaceIDAutoPrompt()
        }
        .onDisappear {
            // ALWAYS re-lock Face ID when leaving the Gallery tab
            isUnlocked = false
            isAuthenticating = false
        }
        .onChange(of: selectedTab) { newTab in
            if newTab != 0 {
                // Re-lock when switching to Camera or Settings tab
                isUnlocked = false
                isSelecting = false
                isAuthenticating = false
                selectedIds.removeAll()
            } else {
                triggerFaceIDAutoPrompt()
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Locked View (Face ID Protection)

    private var lockedState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(Color.white.opacity(0.4))

            VStack(spacing: 8) {
                Text("Galerie Privée")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Accès sécurisé par Face ID")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
            }

            Button(action: {
                authenticateWithFaceID()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "faceid")
                        .font(.system(size: 20))
                    Text("Déverrouiller avec Face ID")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
            }
            .padding(.top, 12)

            Spacer()
        }
    }

    private func triggerFaceIDAutoPrompt() {
        guard !isUnlocked && !isAuthenticating else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.selectedTab == 0 && !self.isUnlocked && !self.isAuthenticating {
                self.authenticateWithFaceID()
            }
        }
    }

    private func authenticateWithFaceID() {
        guard !isUnlocked && !isAuthenticating else { return }
        isAuthenticating = true

        let context = LAContext()
        var error: NSError?

        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        let reason = "Déverrouiller la galerie privée Nano"

        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isUnlocked = success
                if let err = error {
                    print("GalleryView: Face ID error: \(err.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Unlocked Content

    private var unlockedContent: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.top, 56)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if galleryStore.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(galleryStore.items.enumerated()), id: \.element.id) { index, item in
                            ThumbnailCell(
                                item: item,
                                isSelecting: isSelecting,
                                isSelected: selectedIds.contains(item.id),
                                galleryStore: galleryStore
                            )
                            .id(item.id)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ItemFramePreferenceKey.self,
                                        value: [item.id: geo.frame(in: .named("galleryScrollView"))]
                                    )
                                }
                            )
                            .onTapGesture {
                                if isSelecting {
                                    toggleSelection(item.id)
                                } else {
                                    previewIndex = index
                                }
                            }
                        }
                    }
                }
                .coordinateSpace(name: "galleryScrollView")
                .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
                    self.itemFrames = frames
                }
                .highPriorityGesture(
                    isSelecting ? DragGesture(minimumDistance: 0, coordinateSpace: .named("galleryScrollView"))
                        .onChanged { gesture in
                            let loc = gesture.location

                            if let matchedIndex = galleryStore.items.firstIndex(where: { itemFrames[$0.id]?.contains(loc) == true }) {
                                let matchedItem = galleryStore.items[matchedIndex]
                                let currentRow = matchedIndex / 3

                                if startRow == nil {
                                    startRow = currentRow
                                    selectedIds.insert(matchedItem.id)
                                } else if currentRow != startRow {
                                    let initialRow = startRow!
                                    let fromRow = min(initialRow, currentRow)
                                    let toRow = max(initialRow, currentRow)

                                    for r in fromRow...toRow {
                                        let firstInRow = r * 3
                                        let lastInRow = min(firstInRow + 2, galleryStore.items.count - 1)
                                        if firstInRow <= lastInRow {
                                            for i in firstInRow...lastInRow {
                                                selectedIds.insert(galleryStore.items[i].id)
                                            }
                                        }
                                    }
                                } else {
                                    selectedIds.insert(matchedItem.id)
                                }
                            }
                        }
                        .onEnded { _ in
                            startRow = nil
                        } : nil
                )

                // Selection toolbar
                if isSelecting {
                    selectionToolbar
                }
            }
        }
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
                            startRow = nil
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

// MARK: - Single Media Item Preview (with Interactive Video Timeline Scrubber)

struct SingleMediaPreviewView: View {
    let item: MediaItem
    let isCurrent: Bool
    let galleryStore: GalleryStore

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
    }

    @ViewBuilder
    private var photoPreview: some View {
        let url = galleryStore.getFullPath(for: item)
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            ZoomableImageView(image: image)
        }
    }
}

// MARK: - Interactive Video Player with Timeline Scrubber Bar

struct InteractiveVideoPlayerView: View {
    let url: URL
    let isCurrent: Bool

    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isEditingSlider = false
    @State private var timeObserverToken: Any? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                CustomAVPlayerWrapper(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        togglePlayPause()
                    }

                // Play / Pause center indicator overlay
                if !isPlaying {
                    Button(action: togglePlayPause) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                }

                // Bottom Timeline Scrubber Control Bar
                VStack {
                    Spacer()

                    VStack(spacing: 8) {
                        // Slider Scrubber to seek forward / backward
                        Slider(
                            value: Binding(
                                get: { currentTime },
                                set: { newValue in
                                    currentTime = newValue
                                    seekToTime(newValue)
                                }
                            ),
                            in: 0...max(1, duration),
                            onEditingChanged: { editing in
                                isEditingSlider = editing
                            }
                        )
                        .accentColor(.white)

                        // Time Labels
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 12, weight: .regular))
                                .monospacedDigit()
                                .foregroundColor(Color.white.opacity(0.8))

                            Spacer()

                            Text(formatTime(duration))
                                .font(.system(size: 12, weight: .regular))
                                .monospacedDigit()
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.85), Color.black.opacity(0.0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: isCurrent) { active in
            if active {
                player?.play()
                isPlaying = true
            } else {
                player?.pause()
                isPlaying = false
            }
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // Track duration
        if let currentItem = avPlayer.currentItem {
            let asset = currentItem.asset
            Task {
                if let dur = try? await asset.load(.duration) {
                    let seconds = CMTimeGetSeconds(dur)
                    if !seconds.isNaN && seconds > 0 {
                        await MainActor.run {
                            self.duration = seconds
                        }
                    }
                }
            }
        }

        // Periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak avPlayer] time in
            guard avPlayer != nil else { return }
            if !isEditingSlider {
                let seconds = CMTimeGetSeconds(time)
                if !seconds.isNaN {
                    self.currentTime = seconds
                }
            }
        }

        if isCurrent {
            avPlayer.play()
            isPlaying = true
        }
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func seekToTime(_ seconds: Double) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func cleanupPlayer() {
        if let token = timeObserverToken, let player = player {
            player.removeTimeObserver(token)
        }
        timeObserverToken = nil
        player?.pause()
        player = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct CustomAVPlayerWrapper: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> AVPlayerViewContainer {
        let container = AVPlayerViewContainer()
        container.playerLayer.player = player
        container.playerLayer.videoGravity = .resizeAspect
        return container
    }

    func updateUIView(_ uiView: AVPlayerViewContainer, context: Context) {
        uiView.playerLayer.player = player
    }
}

class AVPlayerViewContainer: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
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
