import SwiftUI
import LensCore

struct OccurrenceRow: View {
    let occurrence: Occurrence
    @State private var cropImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cropImage {
                Image(uiImage: cropImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(occurrence.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
        }
        .task {
            if let path = occurrence.cropPath {
                cropImage = StorageService().loadImage(at: path)
            }
        }
    }
}
