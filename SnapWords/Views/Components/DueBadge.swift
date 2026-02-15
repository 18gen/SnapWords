import SwiftUI
import LensCore

struct DueBadge: View {
    let term: Term
    @Environment(AppLocale.self) private var locale

    var body: some View {
        if term.dueDate <= Date() {
            Text(locale("words.due"))
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
        }
    }
}
