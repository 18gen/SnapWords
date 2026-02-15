import SwiftUI
import LensCore

struct FlatTermRow: View {
    let term: Term
    @Environment(AppLocale.self) private var locale

    private var posColor: Color {
        switch term.posEnum {
        case .noun: .blue
        case .verb: .orange
        case .adjective: .green
        case .phrase: .purple
        case .other: .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term.primary)
                .font(.headline)

            HStack(spacing: 6) {
                Text(term.posEnum.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(posColor)

                if !term.translation.isEmpty {
                    Text(term.translation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

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
        }
        .padding(.vertical, 2)
    }
}
