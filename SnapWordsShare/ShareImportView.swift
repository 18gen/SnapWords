import SwiftUI
import SwiftData
import LensCore

struct ShareImportView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var allTokens: [RecognizedToken] = []
    @State private var selectedTokenIDs: Set<UUID> = []
    @State private var isProcessing = false
    @State private var selectedToken: RecognizedToken?
    @State private var showPopover = false
    @State private var zoomOCRTask: Task<Void, Never>?
    @State private var zoomController = ZoomController()
    @State private var currentVisibleRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    private var visibleTokens: [RecognizedToken] {
        allTokens.filter { selectedTokenIDs.contains($0.id) }
    }

    private let ocrService = OCRService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoomableImageView(
                    image: image,
                    zoomController: zoomController,
                    onVisibleRectChanged: { visibleRect in
                        currentVisibleRect = visibleRect
                        handleZoomChange(visibleRect: visibleRect)
                    }
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    zoomButtons
                }
                .padding(.horizontal)
                .padding(.top)

                if isProcessing {
                    ProgressView("Scanning text...")
                        .padding()
                }

                if !allTokens.isEmpty {
                    ScrollView {
                        detectedWordsList
                            .padding(.vertical)
                    }
                }
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
            .sheet(isPresented: $showPopover) {
                if let selectedToken {
                    ShareWordPopoverView(
                        token: selectedToken,
                        allTokens: visibleTokens,
                        image: croppedImage(),
                        onSave: { showPopover = false },
                        onCancel: { showPopover = false }
                    )
                    .presentationDetents([.height(260)])
                    .presentationDragIndicator(.visible)
                }
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
            Text("\(selectedTokenIDs.count)/\(allTokens.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                if selectedTokenIDs.count == allTokens.count {
                    selectedTokenIDs.removeAll()
                } else {
                    selectedTokenIDs = Set(allTokens.map(\.id))
                }
            } label: {
                let allSelected = selectedTokenIDs.count == allTokens.count
                Text(allSelected ? "Deselect All" : "Select All")
                    .font(.caption)
            }
        }
        .padding(.horizontal)
    }

    private var tokenListRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(allTokens) { token in
                tokenRow(token)
                Divider()
                    .padding(.leading, 52)
            }
        }
    }

    private func tokenRow(_ token: RecognizedToken) -> some View {
        let isSelected = selectedTokenIDs.contains(token.id)
        return Button {
            selectedToken = token
            showPopover = true
        } label: {
            HStack(spacing: 12) {
                Button {
                    toggleToken(token)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                        .font(.body)
                }
                .buttonStyle(.plain)

                Text(token.text)
                    .font(.body)
                    .foregroundStyle(isSelected ? .primary : .tertiary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleToken(_ token: RecognizedToken) {
        if selectedTokenIDs.contains(token.id) {
            selectedTokenIDs.remove(token.id)
        } else {
            selectedTokenIDs.insert(token.id)
        }
    }

    private func croppedImage() -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: (currentVisibleRect.origin.x * w).rounded(),
            y: (currentVisibleRect.origin.y * h).rounded(),
            width: (currentVisibleRect.width * w).rounded(),
            height: (currentVisibleRect.height * h).rounded()
        ).intersection(CGRect(x: 0, y: 0, width: w, height: h))

        guard cropRect.width > 0, cropRect.height > 0,
              let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped)
    }

    private func handleZoomChange(visibleRect: CGRect) {
        zoomOCRTask?.cancel()
        zoomOCRTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await processVisibleCrop(visibleRect: visibleRect)
        }
    }

    @MainActor
    private func processVisibleCrop(visibleRect: CGRect) async {
        guard let cgImage = image.cgImage else { return }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: (visibleRect.origin.x * w).rounded(),
            y: (visibleRect.origin.y * h).rounded(),
            width: (visibleRect.width * w).rounded(),
            height: (visibleRect.height * h).rounded()
        ).intersection(CGRect(x: 0, y: 0, width: w, height: h))

        guard cropRect.width > 0, cropRect.height > 0,
              let cropped = cgImage.cropping(to: cropRect) else { return }

        let croppedImage = UIImage(cgImage: cropped)
        isProcessing = true
        do {
            let recognized = try await ocrService.recognizeTokens(from: croppedImage, language: LanguageSettings().targetLanguage)
            allTokens = recognized
            selectedTokenIDs = Set(recognized.map(\.id))
        } catch {}
        isProcessing = false
    }

}
