import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import LensCore

struct ImportView: View {
    @Binding var captureImage: UIImage?
    @Binding var captureFilename: String?
    let initialSourceMode: SourceMode

    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocale.self) private var locale
    @State private var cameraSession = CameraSession()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var allTokens: [RecognizedToken] = []
    @State private var selectedTokenIDs: Set<UUID> = []
    @State private var isProcessing = false
    @State private var selectedToken: RecognizedToken?
    @State private var showPopover = false
    @State private var displayedImage: UIImage?
    @State private var isFrozen = false
    @State private var zoomOCRTask: Task<Void, Never>?
    @State private var zoomController = ZoomController()
    @State private var currentVisibleRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    enum SourceMode: Int, CaseIterable {
        case photo = 0
        case camera = 1
    }

    init(
        captureImage: Binding<UIImage?>,
        captureFilename: Binding<String?>,
        initialSourceMode: SourceMode = .photo
    ) {
        self._captureImage = captureImage
        self._captureFilename = captureFilename
        self.initialSourceMode = initialSourceMode
    }

    private var visibleTokens: [RecognizedToken] {
        allTokens.filter { selectedTokenIDs.contains($0.id) }
    }

    private let ocrService = OCRService()

    var body: some View {
        VStack(spacing: 0) {
            imageArea
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    if displayedImage != nil {
                        zoomButtons
                    }
                }
                .padding(.horizontal)
                .padding(.top)

            if isProcessing {
                ProgressView(locale("lens.scanning"))
                    .padding()
            }

            if !allTokens.isEmpty {
                ScrollView {
                    detectedWordsList
                        .padding(.vertical)
                }
            }
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
        .sheet(isPresented: $showPopover) {
            if let selectedToken, let image = displayedImage ?? cameraSession.frozenImage {
                WordPopoverView(
                    token: selectedToken,
                    allTokens: visibleTokens,
                    image: croppedImage(from: image),
                    onSave: { showPopover = false },
                    onCancel: { showPopover = false }
                )
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            if let img = captureImage {
                Task { await processImage(img) }
            } else if initialSourceMode == .photo {
                showPicker = true
            } else {
                cameraSession.onTokensUpdated = { tokens in
                    allTokens = tokens
                    selectedTokenIDs = Set(tokens.map(\.id))
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
                Text(allSelected ? locale("import.deselect_all") : locale("import.select_all"))
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

    private func freezeCamera() {
        let frozenTokens = cameraSession.latestTokens
        let frozenImage = cameraSession.freezeAndCapture()
        cameraSession.stop()

        if let image = frozenImage {
            displayedImage = image
            allTokens = frozenTokens
            selectedTokenIDs = Set(frozenTokens.map(\.id))
            isFrozen = true
            captureImage = nil
            captureFilename = nil
        }
    }

    private func croppedImage(from image: UIImage) -> UIImage {
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
        currentVisibleRect = visibleRect
        zoomOCRTask?.cancel()
        zoomOCRTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let image = displayedImage else { return }
            await processVisibleCrop(image: image, visibleRect: visibleRect)
        }
    }

    @MainActor
    private func processVisibleCrop(image: UIImage, visibleRect: CGRect) async {
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
        } catch {
            // OCR failed silently
        }
        isProcessing = false
    }

    @MainActor
    private func processImage(_ image: UIImage) async {
        displayedImage = image
        allTokens = []
        selectedTokenIDs = []
        captureImage = nil
        captureFilename = nil
    }
}
