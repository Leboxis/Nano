import SwiftUI

struct FolderPathNode: Identifiable, Equatable {
    let id: String // Directory ID
    let name: String
}

struct KDriveFolderPickerView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var initialDirectoryId: String? = nil
    var initialDirectoryName: String? = nil
    var onSelect: ((_ id: String, _ name: String) -> Void)? = nil

    @State private var pathStack: [FolderPathNode] = [FolderPathNode(id: "1", name: "Racine")]
    @State private var folders: [KDriveFolderItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    // Create new folder states
    @State private var showCreateFolderAlert = false
    @State private var newFolderName = ""
    @State private var isCreatingFolder = false

    private var currentFolder: FolderPathNode {
        pathStack.last ?? FolderPathNode(id: "1", name: "Racine")
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choisir un dossier")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Sélectionnez le dossier de destination kDrive")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.5))
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // Breadcrumb Path Navigation
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(pathStack.enumerated()), id: \.offset) { index, node in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.white.opacity(0.3))
                            }

                            Button(action: {
                                navigateToBreadcrumb(at: index)
                            }) {
                                HStack(spacing: 4) {
                                    if index == 0 {
                                        Image(systemName: "externaldrive.fill")
                                            .font(.system(size: 11))
                                    } else {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 11))
                                    }
                                    Text(node.name)
                                        .font(.system(size: 13, weight: index == pathStack.count - 1 ? .bold : .medium))
                                }
                                .foregroundColor(index == pathStack.count - 1 ? .white : Color.white.opacity(0.5))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(index == pathStack.count - 1 ? Color.white.opacity(0.12) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .background(Color.white.opacity(0.03))

                Divider()
                    .background(Color.white.opacity(0.1))

                // Folder List Content
                ZStack {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Chargement des dossiers...")
                                .font(.system(size: 13))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            Button(action: { loadFolders() }) {
                                Text("Réessayer")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            // Back to parent folder item if not root
                            if pathStack.count > 1 {
                                Button(action: goUpOneLevel) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.turn.up.left")
                                            .foregroundColor(Color.white.opacity(0.5))
                                            .frame(width: 24)
                                        Text(".. (Dossier parent)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color.white.opacity(0.7))
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.clear)
                            }

                            if folders.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "folder")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color.white.opacity(0.2))
                                        Text("Aucun sous-dossier ici")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.white.opacity(0.3))
                                        Text("Vous pouvez créer un nouveau dossier ci-dessous ou sélectionner ce dossier.")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.white.opacity(0.2))
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.vertical, 24)
                                    .padding(.horizontal, 20)
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(folders) { folder in
                                    Button(action: {
                                        enterFolder(folder)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                                                .frame(width: 24)

                                            Text(folder.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white)

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.white.opacity(0.2))
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        .refreshable {
                            loadFolders()
                        }
                    }
                }

                // Bottom Action Bar
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    HStack(spacing: 12) {
                        // Create Folder Button
                        Button(action: {
                            newFolderName = ""
                            showCreateFolderAlert = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Nouveau")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Select Current Folder Button
                        Button(action: selectCurrentFolder) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Choisir \"\(currentFolder.name)\"")
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            }
        }
        .alert("Nouveau dossier", isPresented: $showCreateFolderAlert) {
            TextField("Nom du dossier (ex: Nano)", text: $newFolderName)
            Button("Annuler", role: .cancel) { }
            Button("Créer") {
                createNewFolder()
            }
        } message: {
            Text("Créer un sous-dossier dans \"\(currentFolder.name)\"")
        }
        .onAppear {
            initializePath()
            loadFolders()
        }
    }

    // MARK: - Navigation Helpers

    private func initializePath() {
        let dirId = initialDirectoryId ?? settings.kDriveDirectoryId
        let dirName = initialDirectoryName ?? settings.kDriveDirectoryName

        if dirId != "1" && !dirName.isEmpty && dirName != "Racine (kDrive)" {
            pathStack = [
                FolderPathNode(id: "1", name: "Racine"),
                FolderPathNode(id: dirId, name: dirName)
            ]
        } else {
            pathStack = [FolderPathNode(id: "1", name: "Racine")]
        }
    }

    private func enterFolder(_ folder: KDriveFolderItem) {
        pathStack.append(FolderPathNode(id: String(folder.id), name: folder.name))
        loadFolders()
    }

    private func goUpOneLevel() {
        if pathStack.count > 1 {
            pathStack.removeLast()
            loadFolders()
        }
    }

    private func navigateToBreadcrumb(at index: Int) {
        guard index < pathStack.count else { return }
        pathStack = Array(pathStack.prefix(index + 1))
        loadFolders()
    }

    private func selectCurrentFolder() {
        let selectedId = currentFolder.id
        let selectedName = currentFolder.name == "Racine" ? "Racine (kDrive)" : currentFolder.name

        if let onSelect = onSelect {
            onSelect(selectedId, selectedName)
        } else {
            settings.kDriveDirectoryId = selectedId
            settings.kDriveDirectoryName = selectedName
        }
        dismiss()
    }

    // MARK: - API Calls

    private func loadFolders() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let list = try await KDriveService.shared.fetchSubdirectories(
                    token: settings.kDriveApiToken,
                    driveId: settings.kDriveId,
                    directoryId: currentFolder.id
                )
                await MainActor.run {
                    self.folders = list
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func createNewFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoading = true
        Task {
            do {
                let created = try await KDriveService.shared.createDirectory(
                    token: settings.kDriveApiToken,
                    driveId: settings.kDriveId,
                    parentDirectoryId: currentFolder.id,
                    folderName: newFolderName
                )
                await MainActor.run {
                    enterFolder(created)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Échec de création : \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
