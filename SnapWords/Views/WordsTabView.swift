import SwiftUI
import SwiftData
import PhotosUI
import LensCore

struct WordsTabView: View {
    @Binding var captureImage: UIImage?
    @Binding var captureFilename: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppLocale.self) private var locale
    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]
    @Query(sort: \Term.createdAt, order: .reverse) private var allTerms: [Term]

    @State private var importConfig: ImportSheetConfig?
    @State private var showNewFolder = false
    @State private var searchText = ""
    @State private var isFlatMode = false
    @State private var showPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?

    private var topLevelFolders: [Folder] {
        allFolders
            .filter { $0.parent == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
    }

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var searchResults: [Term] {
        let query = searchText.lowercased()
        return allTerms.filter {
            $0.primary.lowercased().contains(query) ||
            $0.lemma.lowercased().contains(query) ||
            $0.translationJa.contains(query) ||
            ($0.folder?.name.lowercased().contains(query) == true)
        }
    }

    private var matchingFolders: [Folder] {
        guard isSearching else { return [] }
        let query = searchText.lowercased()
        return allFolders.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            wordsList
                .sheet(item: $importConfig) { config in
                    importSheet(config: config)
                }
                .sheet(isPresented: $showNewFolder) {
                    FolderFormView()
                }
                .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
                .onChange(of: pickerItem) { _, newValue in
                    guard let newValue else { return }
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            captureImage = img
                            pickerItem = nil
                        }
                    }
                }
                .onChange(of: captureImage) { _, newValue in
                    if newValue != nil && importConfig == nil {
                        importConfig = ImportSheetConfig(sourceMode: .photo)
                    }
                }
        }
    }

    // MARK: - Subviews

    private var wordsList: some View {
        let title = locale("tab.words")
        return List {
            if isSearching {
                searchResultsContent
            } else if isFlatMode {
                flatModeContent
            } else {
                folderModeContent
            }

            // Add button when empty (no terms)
            if allTerms.isEmpty && !isSearching {
                addWordsRow
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: Text(locale("words.search")))
        .navigationDestination(for: Term.self) { term in
            TermDetailView(term: term)
        }
        .navigationDestination(for: Folder.self) { folder in
            WordListView(folder: folder)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Button {
                        isFlatMode.toggle()
                    } label: {
                        Image(systemName: isFlatMode ? "list.bullet" : "folder")
                            .foregroundStyle(isFlatMode ? Color.accentColor : Color.secondary)
                    }

                    addMenuButton
                }
            }
        }
    }

    private var addWordsRow: some View {
        Button {
            showPhotoPicker = true
        } label: {
            HStack {
                Spacer()
                Label(locale("words.add_words"), systemImage: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }
            .padding(.vertical, 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Folder Mode

    @ViewBuilder
    private var folderModeContent: some View {
        ForEach(topLevelFolders) { folder in
            NavigationLink(value: folder) {
                FolderRow(folder: folder)
            }
        }
        .onDelete(perform: deleteFolders)
    }

    // MARK: - Flat Mode

    @ViewBuilder
    private var flatModeContent: some View {
        ForEach(allTerms) { term in
            NavigationLink(value: term) {
                FlatTermRow(term: term)
            }
        }
        .onDelete(perform: deleteTermsFlat)
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsContent: some View {
        if !matchingFolders.isEmpty {
            Section(locale("words.folders_section")) {
                ForEach(matchingFolders) { folder in
                    NavigationLink(value: folder) {
                        FolderRow(folder: folder)
                    }
                }
            }
        }

        if !searchResults.isEmpty {
            Section(locale("tab.words")) {
                ForEach(searchResults) { term in
                    NavigationLink(value: term) {
                        FlatTermRow(term: term)
                    }
                }
            }
        }

        if matchingFolders.isEmpty && searchResults.isEmpty {
            ContentUnavailableView.search(text: searchText)
        }
    }

    private var addMenuButton: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label(locale("menu.scan_photo"), systemImage: "photo")
            }

            Button {
                importConfig = ImportSheetConfig(sourceMode: .camera)
            } label: {
                Label(locale("import.camera"), systemImage: "camera")
            }

            Divider()

            Button {
                showNewFolder = true
            } label: {
                Label(locale("menu.new_folder"), systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private func importSheet(config: ImportSheetConfig) -> some View {
        NavigationStack {
            ImportView(
                captureImage: $captureImage,
                captureFilename: $captureFilename,
                initialSourceMode: config.sourceMode
            )
        }
    }

    private func deleteFolders(at offsets: IndexSet) {
        let unfiledID = FolderConstants.unfiledFolderID
        for index in offsets {
            let folder = topLevelFolders[index]
            guard !folder.isSystem else { continue }
            safeDeleteFolder(folder, unfiledID: unfiledID)
        }
    }

    private func deleteTermsFlat(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(allTerms[index])
        }
    }

    private func safeDeleteFolder(_ folder: Folder, unfiledID: UUID) {
        let unfiled = allFolders.first { $0.id == unfiledID }
        for term in folder.terms {
            term.folder = unfiled
        }
        for child in folder.children {
            child.parent = folder.parent
        }
        modelContext.delete(folder)
    }
}
