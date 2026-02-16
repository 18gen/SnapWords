import SwiftUI
import LensCore

struct TermRow: View {
    let term: Term

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term.primary)
                .font(.headline)

            if !term.translation.isEmpty {
                Text(term.translation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
