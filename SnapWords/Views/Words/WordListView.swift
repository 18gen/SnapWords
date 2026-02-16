import SwiftUI
import SwiftData
import PhotosUI
import LensCore

struct WordListView: View {
    let folder: Folder

    @Environment(\.modelContext) private var modelContext
    @Environment(AppLocale.self) private var locale
    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]
    @State private var searchText = ""
    @State private var showNewSubfolder = false
    @State private var importConfig: ImportSheetConfig?
    @State private var showPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    private var sortedChildren: [Folder] {
        folder.children.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    private var sortedTerms: [Term] {
        folder.terms.sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredTerms: [Term] {
        guard !searchText.isEmpty else { return sortedTerms }
        let query = searchText.lowercased()
        return sortedTerms.filter {
            $0.primary.lowercased().contains(query) ||
            $0.lemma.lowercased().contains(query) ||
            $0.translation.contains(query)
        }
    }

    var body: some View {
        List {
            if !sortedChildren.isEmpty && searchText.isEmpty {
                Section(locale("folders.subfolders")) {
                    ForEach(sortedChildren) { child in
                        NavigationLink(value: child) {
                            FolderRow(folder: child)
                        }
                    }
                    .onDelete(perform: deleteSubfolders)
                }
            }

            Section {
                ForEach(filteredTerms) { term in
                    NavigationLink(value: term) {
                        TermRow(term: term)
                    }
                }
                .onDelete(perform: deleteTerms)
            }
        }
        .navigationTitle(folder.displayName(locale: locale))
        .searchable(text: $searchText, prompt: Text(locale("words.search")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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

                    if folder.canAddSubfolder {
                        Divider()
                        Button {
                            showNewSubfolder = true
                        } label: {
                            Label(locale("menu.new_subfolder"), systemImage: "folder.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    selectedImage = img
                    importConfig = ImportSheetConfig(sourceMode: .photo)
                    pickerItem = nil
                }
            }
        }
        .sheet(isPresented: $showNewSubfolder) {
            FolderFormView(parentFolder: folder)
                .environment(locale)
        }
        .sheet(item: $importConfig) { config in
            NavigationStack {
                ImportView(
                    captureImage: $selectedImage,
                    captureFilename: .constant(nil),
                    initialSourceMode: config.sourceMode
                )
            }
            .environment(locale)
        }
        .overlay {
            if filteredTerms.isEmpty && sortedChildren.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    locale("folders.no_words"),
                    systemImage: "folder"
                )
            }
        }
    }

    private func deleteTerms(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredTerms[index])
        }
    }

    private func deleteSubfolders(at offsets: IndexSet) {
        let unfiledID = FolderConstants.unfiledFolderID
        let unfiled = allFolders.first { $0.id == unfiledID }
        for index in offsets {
            let child = sortedChildren[index]
            guard !child.isSystem else { continue }
            for term in child.terms {
                term.folder = unfiled
            }
            for grandchild in child.children {
                grandchild.parent = folder
            }
            modelContext.delete(child)
        }
    }
}
