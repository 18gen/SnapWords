import SwiftUI
import SwiftData
import LensCore
import Translation

struct WordPopoverView: View {
    let token: RecognizedToken
    let allTokens: [RecognizedToken]
    let image: UIImage
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(AppLocale.self) private var locale
    @State private var primary: String
    @State private var translationText: String = ""
    @State private var isSaving = false
    @State private var selectedFolderID: UUID = FolderConstants.unfiledFolderID
    @State private var isTranslating = true

    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]

    @State private var translationConfig: TranslationSession.Configuration?

    private let pos: POS
    private let lemma: String
    private let normService = NormalizationService()
    private let contextExtractor = ContextExtractor()
    private let langSettings = LanguageSettings()

    init(
        token: RecognizedToken,
        allTokens: [RecognizedToken],
        image: UIImage,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.token = token
        self.allTokens = allTokens
        self.image = image
        self.onSave = onSave
        self.onCancel = onCancel

        let guess = POSService().guess(for: token.text)
        self.pos = guess.pos
        self.lemma = guess.lemma

        let norm = NormalizationService()
        _primary = State(initialValue: norm.makePrimary(
            raw: token.text, lemma: guess.lemma, pos: guess.pos
        ))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Translation (main focus)
            VStack(spacing: 4) {
                if isTranslating {
                    ProgressView()
                        .frame(height: 28)
                } else {
                    Text(translationText.isEmpty ? locale("review.no_translation") : translationText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(translationText.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.center)
                }
                Text(primary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            // Folder selection (single-select)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allFolders) { folder in
                        Button {
                            selectedFolderID = folder.id
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: folder.iconName)
                                    .font(.caption2)
                                Text(folder.name)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                selectedFolderID == folder.id
                                    ? Color(hex: folder.colorHex).opacity(0.2)
                                    : Color(.systemGray5)
                            )
                            .foregroundStyle(
                                selectedFolderID == folder.id
                                    ? Color(hex: folder.colorHex)
                                    : .primary
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text(locale("word.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await save() }
                } label: {
                    Text(locale("word.save"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .translationTask(translationConfig) { session in
            do {
                let response = try await session.translate(primary)
                translationText = response.targetText
            } catch {
                // Translation unavailable
            }
            isTranslating = false
        }
        .task {
            triggerTranslation()
        }
    }

    private func triggerTranslation() {
        let source = langSettings.sourceLanguage
        let target = langSettings.targetLanguage
        guard source != target else {
            isTranslating = false
            return
        }
        translationConfig = .init(
            source: Locale.Language(identifier: source),
            target: Locale.Language(identifier: target)
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let storage = StorageService()
        let context = contextExtractor.context(for: token, tokens: allTokens)

        do {
            let screenshotPath = try storage.saveScreenshot(image: image)

            var cropPath: String?
            if let highlighted = highlightedImage(token: token) {
                cropPath = try storage.saveCrop(image: highlighted)
            }

            let container = try SharedModelContainer.create()
            let modelContext = ModelContext(container)

            let posStr = pos.rawValue
            let lemmaLower = lemma.lowercased()
            let descriptor = FetchDescriptor<Term>(
                predicate: #Predicate<Term> { term in
                    term.pos == posStr && term.lemma == lemmaLower
                }
            )

            let existing = try modelContext.fetch(descriptor)
            let term: Term

            if let found = existing.first {
                term = found
                term.primary = primary
                if !translationText.isEmpty {
                    term.translationJa = translationText
                }
            } else {
                term = Term(
                    primary: primary,
                    lemma: lemmaLower,
                    pos: pos,
                    translationJa: translationText,
                    articleMode: false
                )
                modelContext.insert(term)
            }

            // Associate selected folder
            let folderID = selectedFolderID
            let folderDescriptor = FetchDescriptor<Folder>(
                predicate: #Predicate<Folder> { f in
                    f.id == folderID
                }
            )
            if let folder = try modelContext.fetch(folderDescriptor).first {
                term.folder = folder
            }

            let occurrence = Occurrence(
                rawText: token.text,
                context: context,
                screenshotPath: screenshotPath,
                cropPath: cropPath,
                sourceLabel: nil
            )
            occurrence.term = term
            modelContext.insert(occurrence)

            try modelContext.save()
            onSave()
        } catch {
            print("Save failed: \(error)")
        }
    }

    private func highlightedImage(token: RecognizedToken) -> UIImage? {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            image.draw(at: .zero)

            let rect = token.boundingBox
            let highlightColor = UIColor.systemYellow.withAlphaComponent(0.35)

            ctx.cgContext.setFillColor(highlightColor.cgColor)
            ctx.cgContext.fill(rect)
        }
    }
}
