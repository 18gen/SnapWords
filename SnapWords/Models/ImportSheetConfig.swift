import Foundation

struct ImportSheetConfig: Identifiable {
    let id = UUID()
    let sourceMode: ImportView.SourceMode
}
