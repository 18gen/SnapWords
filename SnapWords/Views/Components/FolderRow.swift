import SwiftUI
import LensCore

struct FolderRow: View {
    let folder: Folder
    @Environment(AppLocale.self) private var locale

    private var childCount: Int {
        folder.children.count
    }

    var body: some View {
        HStack(spacing: 12) {
            FolderIcon(iconName: folder.iconName, colorHex: folder.colorHex)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName(locale: locale))
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(locale("folders.word_count \(folder.terms.count)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if childCount > 0 {
                        Text("\u{00B7}")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(locale("folders.subfolders_count \(childCount)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }
}
