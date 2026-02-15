import Foundation
import SwiftData

public enum FolderBootstrap {
    @MainActor
    public static func ensureUnfiledFolder(in container: ModelContainer) {
        let context = container.mainContext
        let targetID = FolderConstants.unfiledFolderID

        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate<Folder> { folder in
                folder.id == targetID
            }
        )

        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let unfiled = Folder(
                    id: FolderConstants.unfiledFolderID,
                    name: FolderConstants.unfiledFolderName,
                    iconName: FolderConstants.unfiledFolderIcon,
                    colorHex: FolderConstants.unfiledFolderColor,
                    isSystem: true
                )
                context.insert(unfiled)
                try context.save()
            }
        } catch {
            print("FolderBootstrap: Failed to ensure Unfiled folder: \(error)")
        }
    }
}
