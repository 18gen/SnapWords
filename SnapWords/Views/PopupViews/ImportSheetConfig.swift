import Foundation

struct ImportSheetConfig: Identifiable {
    let id = UUID()
    let sourceMode: ImportView.SourceMode
    let defaultFolderID: UUID?

    init(sourceMode: ImportView.SourceMode, defaultFolderID: UUID? = nil) {
        self.sourceMode = sourceMode
        self.defaultFolderID = defaultFolderID
    }
}
