import SwiftUI
import LensCore

struct TermRow: View {
    let term: Term

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
        }
        .padding(.vertical, 2)
    }
}
