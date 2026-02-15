import SwiftUI
import LensCore

struct FlatTermRow: View {
    let term: Term
    @Environment(AppLocale.self) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(term.primary)
                    .font(.headline)

                Spacer()

                DueBadge(term: term)
            }

            if !term.translationJa.isEmpty {
                Text(term.translationJa)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(term.posEnum.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary)
                    .clipShape(Capsule())

                if let folder = term.folder {
                    HStack(spacing: 3) {
                        Image(systemName: folder.iconName)
                            .font(.system(size: 8))
                        Text(folder.displayName(locale: locale))
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: folder.colorHex).opacity(0.15))
                    .foregroundStyle(Color(hex: folder.colorHex))
                    .clipShape(Capsule())
                }

                Text(locale("words.occurrences \(term.occurrences.count)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
