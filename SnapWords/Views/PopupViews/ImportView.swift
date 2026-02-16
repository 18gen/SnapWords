import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import LensCore

struct ImportView: View {
    @Binding var captureImage: UIImage?
    @Binding var captureFilename: String?
    let initialSourceMode: SourceMode
    let defaultFolderID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocale.self) private var locale
    @State private var cameraSession = CameraSession()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var allTokens: [RecognizedToken] = []
    @State private var isProcessing = false
    @State private var selectedToken: RecognizedToken?
    @State private var displayedImage: UIImage?
    @State private var isFrozen = false
    @State private var zoomController = ZoomController()
    @State private var currentVisibleRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    @Query(sort: \Term.dueDate) private var savedTerms: [Term]

    enum SourceMode: Int, CaseIterable {
        case photo = 0
        case camera = 1
    }

    init(
        captureImage: Binding<UIImage?>,
        captureFilename: Binding<String?>,
        initialSourceMode: SourceMode = .photo,
        defaultFolderID: UUID? = nil
    ) {
        self._captureImage = captureImage
        self._captureFilename = captureFilename
        self.initialSourceMode = initialSourceMode
        self.defaultFolderID = defaultFolderID
    }

    private var visibleTokens: [RecognizedToken] {
        guard let image = displayedImage, let cgImage = image.cgImage else {
            return allTokens
        }
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
        VStack(spacing: 0) {
            imageArea
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0/9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    if displayedImage != nil {
                        zoomButtons
                    }
                }
                .padding(.horizontal)
                .padding(.top)

            if !allTokens.isEmpty {
                ScrollView {
                    detectedWordsList
                        .padding(.vertical)
                }
            } else if displayedImage != nil {
                VStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(locale("lens.scanning"))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer(minLength: 0)
        }
        .navigationTitle(locale("import.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                        .font(.body.weight(.semibold))
                }
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await processImage(img)
                }
            }
        }
        .onChange(of: showPicker) { _, isShowing in
            if !isShowing && pickerItem == nil && displayedImage == nil && captureImage == nil {
                dismiss()
            }
        }
        .onChange(of: captureImage) { _, newValue in
            if let img = newValue {
                Task { await processImage(img) }
            }
        }
        .sheet(item: $selectedToken) { token in
            Group {
                if let image = displayedImage {
                    WordPopoverView(
                        token: token,
                        allTokens: allTokens,
                        image: image,
                        visibleRect: currentVisibleRect,
                        defaultFolderID: defaultFolderID,
                        onSave: { selectedToken = nil },
                        onCancel: { selectedToken = nil }
                    )
                }
            }
            .environment(locale)
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(420)])
        }
        .onAppear {
            if let img = captureImage {
                Task { await processImage(img) }
            } else if initialSourceMode == .photo {
                showPicker = true
            } else {
                cameraSession.onTokensUpdated = { tokens in
                    allTokens = tokens
                }
                cameraSession.start()
            }
        }
        .onDisappear {
            cameraSession.stop()
        }
    }

    // MARK: - Image Area

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
    private var imageArea: some View {
        if let displayedImage {
            ZoomableImageView(
                image: displayedImage,
                zoomController: zoomController,
                onVisibleRectChanged: { visibleRect in
                    handleZoomChange(visibleRect: visibleRect)
                }
            )
        } else if initialSourceMode == .camera {
            cameraPreview
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(locale("import.choose_photo"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
        }
    }

    @ViewBuilder
    private var cameraPreview: some View {
        if cameraSession.isRunning {
            CameraPreviewView(session: cameraSession.session)
                .overlay(alignment: .bottom) {
                    Button {
                        freezeCamera()
                    } label: {
                        Image(systemName: "circle.inset.filled")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding(.bottom, 16)
                }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text(locale("import.camera"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
        }
    }

    // MARK: - Detected Words List

    @ViewBuilder
    private var detectedWordsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            tokenListHeader
            tokenListRows
        }
    }

    private var tokenListHeader: some View {
        HStack {
            Text(locale("import.detected_words"))
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

    private func freezeCamera() {
        let frozenImage = cameraSession.freezeAndCapture()
        cameraSession.stop()

        if let image = frozenImage {
            isFrozen = true
            Task { await processImage(image) }
        }
    }

    private func handleZoomChange(visibleRect: CGRect) {
        currentVisibleRect = visibleRect
    }

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
    private func processImage(_ rawImage: UIImage) async {
        let image = normalizeOrientation(rawImage)
        displayedImage = image
        allTokens = []
        isProcessing = true
        captureImage = nil
        captureFilename = nil

        do {
            let recognized = try await ocrService.recognizeTokens(
                from: image,
                language: LanguageSettings().targetLanguage
            )
            allTokens = recognized
        } catch {
            // OCR failed silently
        }
        isProcessing = false
    }
}
