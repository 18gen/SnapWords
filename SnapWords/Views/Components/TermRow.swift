import SwiftUI
import LensCore

struct TermRow: View {
    let term: Term

    var body: some View {
        Text(term.primary)
            .font(.headline)
            .padding(.vertical, 2)
    }
}
