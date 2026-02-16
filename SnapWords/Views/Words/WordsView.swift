import SwiftUI
import SwiftData
import LensCore

struct WordsView: View {
    var onAddWords: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppLocale.self) private var locale
    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]
    @Query(sort: \Term.createdAt, order: .reverse) private var allTerms: [Term]

    @State private var searchText = ""

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
            $0.translation.contains(query) ||
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
        }
    }

    // MARK: - Subviews

    private var wordsList: some View {
        let title = locale("tab.library")
        return List {
            if isSearching {
                searchResultsContent
            } else {
                folderModeContent
            }

            if allTerms.isEmpty && !isSearching {
                addWordsRow
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text(locale("words.search")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onAddWords()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: Term.self) { term in
            TermDetailView(term: term)
                .environment(locale)
        }
        .navigationDestination(for: Folder.self) { folder in
            WordListView(folder: folder)
                .environment(locale)
        }
    }

    private var addWordsRow: some View {
        Button {
            onAddWords()
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
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        }
        .onDelete(perform: deleteFolders)
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

    private func deleteFolders(at offsets: IndexSet) {
        let unfiledID = FolderConstants.unfiledFolderID
        for index in offsets {
            let folder = topLevelFolders[index]
            guard !folder.isSystem else { continue }
            safeDeleteFolder(folder, unfiledID: unfiledID)
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
