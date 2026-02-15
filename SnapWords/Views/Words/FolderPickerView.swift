import SwiftUI
import SwiftData
import LensCore

struct FolderPickerView: View {
    @Bindable var term: Term
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocale.self) private var locale
    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]

    private var flattenedFolders: [(folder: Folder, indent: Int)] {
        let topLevel = allFolders
            .filter { $0.parent == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
        var result: [(Folder, Int)] = []
        func flatten(_ folder: Folder, indent: Int) {
            result.append((folder, indent))
            let sorted = folder.children.sorted {
                $0.name.localizedCompare($1.name) == .orderedAscending
            }
            for child in sorted {
                flatten(child, indent: indent + 1)
            }
        }
        for folder in topLevel {
            flatten(folder, indent: 0)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(flattenedFolders, id: \.folder.id) { item in
                    Button {
                        term.folder = item.folder
                    } label: {
                        HStack(spacing: 12) {
                            HStack(spacing: 0) {
                                ForEach(0..<item.indent, id: \.self) { _ in
                                    Spacer().frame(width: 20)
                                }
                                Image(systemName: item.folder.iconName)
                                    .foregroundStyle(Color(hex: item.folder.colorHex))
                                    .frame(width: 24)
                            }
                            Text(item.folder.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if term.folder?.id == item.folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(locale("folder_picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale("folder_picker.done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
