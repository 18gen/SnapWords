import LensCore

extension Folder {
    func displayName(locale: AppLocale) -> String {
        if isSystem && id == FolderConstants.unfiledFolderID {
            return locale("folder.unfiled")
        }
        return name
    }
}
