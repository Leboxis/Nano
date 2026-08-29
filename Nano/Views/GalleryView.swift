import SwiftUI
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
            galleryStore.refresh()
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
                galleryStore.refresh()
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

        ShareSheetPresenter.present(items: urls)
    }

    private func deleteSelected() {
        galleryStore.deleteItems(ids: selectedIds)
        selectedIds.removeAll()
        if galleryStore.items.isEmpty {
            isSelecting = false
        }
    }
}
