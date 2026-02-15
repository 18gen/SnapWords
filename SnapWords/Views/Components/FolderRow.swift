import SwiftUI
import LensCore

struct FolderRow: View {
    let folder: Folder
    @Environment(AppLocale.self) private var locale

    private var dueCount: Int {
        let now = Date()
        return folder.allTermsRecursive.filter { $0.dueDate <= now }.count
    }

    private var childCount: Int {
        folder.children.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.iconName)
                .font(.title2)
                .foregroundStyle(Color(hex: folder.colorHex))
                .frame(width: 32)

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

            if dueCount > 0 {
                Text("\(dueCount)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
