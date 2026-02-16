import SwiftUI
import SwiftData
import LensCore

struct ShareImportView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var normalizedImage: UIImage?
    @State private var allTokens: [RecognizedToken] = []
    @State private var isProcessing = false
    @State private var selectedToken: RecognizedToken?
    @State private var zoomController = ZoomController()
    @State private var currentVisibleRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    @Query(sort: \Term.dueDate) private var savedTerms: [Term]

    private var displayImage: UIImage { normalizedImage ?? image }

    private var visibleTokens: [RecognizedToken] {
        guard let cgImage = displayImage.cgImage else { return allTokens }
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        guard imgW > 0, imgH > 0 else { return allTokens }

        let visiblePixelRect = CGRect(
            x: currentVisibleRect.origin.x * imgW,
            y: currentVisibleRect.origin.y * imgH,
            width: currentVisibleRect.width * imgW,
            height: currentVisibleRect.height * imgH
        )
        return allTokens.filter { token in
            token.boundingBox.intersects(visiblePixelRect)
        }
    }

    private let ocrService = OCRService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoomableImageView(
                    image: displayImage,
                    zoomController: zoomController,
                    onVisibleRectChanged: { visibleRect in
                        currentVisibleRect = visibleRect
                    }
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0/9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    zoomButtons
                }
                .padding(.horizontal)
                .padding(.top)

                if !allTokens.isEmpty {
                    ScrollView {
                        detectedWordsList
                            .padding(.vertical)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Scanning text...")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer(minLength: 0)
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .sheet(item: $selectedToken) { token in
                Group {
                    ShareWordPopoverView(
                        token: token,
                        allTokens: allTokens,
                        image: displayImage,
                        visibleRect: currentVisibleRect,
                        onSave: { selectedToken = nil },
                        onCancel: { selectedToken = nil }
                    )
                }
                .presentationDragIndicator(.visible)
                .presentationDetents([.height(420)])
            }
            .task {
                await processImage()
            }
        }
    }

    // MARK: - Subviews

    private var zoomButtons: some View {
        VStack(spacing: 4) {
            Button {
                zoomController.zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }

            Divider()
                .frame(width: 32)

            Button {
                zoomController.zoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(8)
    }

    @ViewBuilder
    private var detectedWordsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            tokenListHeader
            tokenListRows
        }
    }

    private var tokenListHeader: some View {
        HStack {
            Text("Detected Words")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var tokenListRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(visibleTokens) { token in
                tokenRow(token)
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    private func isSaved(_ token: RecognizedToken) -> Bool {
        let normalized = token.normalizedText
        return savedTerms.contains { $0.lemma == normalized }
    }

    private func tokenRow(_ token: RecognizedToken) -> some View {
        Button {
            selectedToken = token
        } label: {
            HStack(spacing: 12) {
                Text(token.text)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSaved(token) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.361, green: 0.722, blue: 0.478))
                        .font(.body)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    @MainActor
    private func processImage() async {
        isProcessing = true
        let normalized = normalizeOrientation(image)
        normalizedImage = normalized
        do {
            let recognized = try await ocrService.recognizeTokens(
                from: normalized,
                language: LanguageSettings().targetLanguage
            )
            allTokens = recognized
        } catch {
            // OCR failed silently
        }
        isProcessing = false
    }
}
