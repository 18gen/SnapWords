import SwiftUI
import SwiftData
import LensCore
import Translation

struct WordPopoverView: View {
    let token: RecognizedToken
    let allTokens: [RecognizedToken]
    let image: UIImage
    let visibleRect: CGRect
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(AppLocale.self) private var locale
    @Environment(\.modelContext) private var modelContext
    @State private var primary: String
    @State private var translationText: String = ""
    @State private var isSaving = false
    @State private var selectedFolderID: UUID = FolderConstants.unfiledFolderID
    @State private var isTranslating = true
    @State private var isSameLanguage = false
    @State private var showDictionary = false
    @State private var definitionText: String = ""
    @State private var exampleText: String = ""
    @State private var exampleTranslationText: String = ""
    @State private var etymologyText: String = ""
    @State private var synonymsText: String = ""
    @State private var antonymsText: String = ""

    @Query(sort: \Folder.sortOrder) private var allFolders: [Folder]

    @State private var translationConfig: TranslationSession.Configuration?

    @State private var pos: POS
    @State private var lemma: String
    private let normService = NormalizationService()
    private let contextExtractor = ContextExtractor()
    private let langSettings = LanguageSettings()
    private let groqService = GroqService()

    init(
        token: RecognizedToken,
        allTokens: [RecognizedToken],
        image: UIImage,
        visibleRect: CGRect,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.token = token
        self.allTokens = allTokens
        self.image = image
        self.visibleRect = visibleRect
        self.onSave = onSave
        self.onCancel = onCancel

        let guess = POSService().guess(for: token.text)
        _pos = State(initialValue: guess.pos)
        _lemma = State(initialValue: guess.lemma)

        let lang = LanguageSettings().targetLanguage
        let norm = NormalizationService()
        _primary = State(initialValue: norm.makePrimary(
            raw: token.text, lemma: guess.lemma, pos: guess.pos, language: lang
        ))
    }

    // MARK: - POS Color

    private var posColor: Color {
        switch pos {
        case .noun: Color(red: 0.356, green: 0.553, blue: 0.937)    // #5B8DEF muted blue
        case .verb: Color(red: 0.878, green: 0.533, blue: 0.302)    // #E0884D muted orange
        case .adjective: Color(red: 0.361, green: 0.722, blue: 0.478) // #5CB87A muted green
        case .phrase: Color(red: 0.608, green: 0.494, blue: 0.784)   // #9B7EC8 muted purple
        case .other: .gray
        }
    }

    // MARK: - Body

    @State private var headerVisible = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {

                    // --- Word Section ---
                    VStack(spacing: 8) {
                        Text(primary)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)

                        if !isTranslating {
                            Text(pos.displayName(for: langSettings.nativeLanguage))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(posColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(posColor.opacity(0.12))
                                .clipShape(Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .onScrollVisibilityChange { visible in
                        headerVisible = visible
                    }

                    Divider().frame(height: 1).overlay(Color(.separator))

                    // --- Translation Section ---
                    Group {
                        if isTranslating {
                            ProgressView()
                                .controlSize(.regular)
                                .frame(height: 28)
                                .frame(maxWidth: .infinity)
                        } else if isSameLanguage {
                            Button {
                                showDictionary = true
                            } label: {
                                Label(locale("word.look_up"), systemImage: "book.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 12) {
                                Text(translationText.isEmpty ? locale("review.no_translation") : translationText)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundStyle(translationText.isEmpty ? .tertiary : .primary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)

                                // Rich details
                                if !etymologyText.isEmpty || !exampleText.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        if !etymologyText.isEmpty {
                                            Text(etymologyText)
                                                .font(.callout)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 10)
                                        }

                                        if !etymologyText.isEmpty && !exampleText.isEmpty {
                                            Divider()
                                        }

                                        if !exampleText.isEmpty {
                                            VStack(alignment: .leading, spacing: 2) {
                                                boldedExample(exampleText, word: primary)
                                                    .font(.callout)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                if !exampleTranslationText.isEmpty {
                                                    boldedExample(exampleTranslationText, word: translationText)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 10)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .background(.fill.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.3), value: isTranslating)

                    Divider().frame(height: 1).overlay(Color(.separator))

                    // --- Folder Selector ---
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Folder")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(allFolders) { folder in
                                    let isSelected = selectedFolderID == folder.id
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedFolderID = folder.id
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: folder.iconName)
                                                .font(.caption2)
                                            Text(folder.name)
                                                .font(.caption)
                                                .fontWeight(isSelected ? .semibold : .regular)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            isSelected
                                                ? Color(hex: folder.colorHex).opacity(0.18)
                                                : Color(.systemGray6)
                                        )
                                        .foregroundStyle(
                                            isSelected
                                                ? Color(hex: folder.colorHex)
                                                : .secondary
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(
                                                    isSelected
                                                        ? Color(hex: folder.colorHex).opacity(0.3)
                                                        : .clear,
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            // --- Action Buttons (pinned) ---
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text(locale("word.cancel"))
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    Task { await save() }
                } label: {
                    Text(locale("word.save"))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .padding(.top, 8)
        }
        .overlay(alignment: .top) {
            Text(primary)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.bar)
                .opacity(headerVisible ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: headerVisible)
        }
        .translationTask(translationConfig) { session in
            do {
                let wordResponse = try await session.translate(primary)
                translationText = wordResponse.targetText
                if !exampleText.isEmpty {
                    let exResponse = try await session.translate(exampleText)
                    exampleTranslationText = exResponse.targetText
                }
            } catch {
                // Translation unavailable
            }
            isTranslating = false
        }
        .sheet(isPresented: $showDictionary) {
            DictionaryView(term: primary)
        }
        .task {
            await triggerTranslation()
        }
    }

    private func triggerTranslation() async {
        let native = langSettings.nativeLanguage
        let target = langSettings.targetLanguage
        guard native != target else {
            isSameLanguage = true
            isTranslating = false
            return
        }

        var groqResult: GroqRichResult?

        // Level 1: Vision analysis
        if let crop = contextExtractor.imageCrop(for: token, allTokens: allTokens, image: image) {
            groqResult = try? await groqService.analyzeWithVision(
                word: token.text, imageCrop: crop,
                sourceLanguage: target, targetLanguage: native
            )
        }

        // Level 2: Text analysis (if vision failed or returned empty translation)
        if groqResult == nil || groqResult?.translation.isEmpty == true {
            let context = contextExtractor.context(for: token, tokens: allTokens)
            if let textResult = try? await groqService.analyzeWithText(
                word: token.text, context: context,
                sourceLanguage: target, targetLanguage: native
            ) {
                // Merge: prefer text result, but keep vision rich data if text fields are empty
                if let prior = groqResult, textResult.translation.isEmpty {
                    groqResult = prior
                } else {
                    groqResult = textResult
                }
            }
        }

        // Apply Groq results (English definition, example, POS)
        if let result = groqResult {
            applyResult(result, language: target)
        }

        // ALWAYS trigger Apple Translation for high-quality native language
        translationConfig = .init(
            source: Locale.Language(identifier: target),
            target: Locale.Language(identifier: native)
        )
    }

    private func applyResult(_ result: GroqRichResult, language: String) {
        definitionText = result.definition
        exampleText = result.example
        etymologyText = result.etymology
        synonymsText = result.synonyms
        antonymsText = result.antonyms
        pos = result.pos
        lemma = result.lemma

        primary = normService.makePrimary(
            raw: token.text, lemma: result.lemma,
            pos: result.pos, language: language
        )

        isTranslating = false
    }

    private func boldedExample(_ sentence: String, word: String) -> Text {
        guard !word.isEmpty else { return Text(sentence) }
        guard let range = sentence.range(of: word, options: .caseInsensitive) else { return Text(sentence) }
        let before = String(sentence[sentence.startIndex..<range.lowerBound])
        let match = String(sentence[range])
        let after = String(sentence[range.upperBound...])
        return Text(before) + Text(match).bold() + Text(after)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
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
                    term.translation = translationText
                }
                if !definitionText.isEmpty {
                    term.definition = definitionText
                }
                if !exampleText.isEmpty {
                    term.example = exampleText
                }
                if !exampleTranslationText.isEmpty {
                    term.exampleTranslation = exampleTranslationText
                }
                if !etymologyText.isEmpty {
                    term.etymology = etymologyText
                }
                if !synonymsText.isEmpty {
                    term.synonyms = synonymsText
                }
                if !antonymsText.isEmpty {
                    term.antonyms = antonymsText
                }
            } else {
                term = Term(
                    primary: primary,
                    lemma: lemmaLower,
                    pos: pos,
                    translation: translationText,
                    definition: definitionText,
                    example: exampleText,
                    exampleTranslation: exampleTranslationText,
                    etymology: etymologyText,
                    synonyms: synonymsText,
                    antonyms: antonymsText,
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

            if !isSameLanguage, term.snapImagePath == nil {
                if let highlighted = highlightedImage(token: token) {
                    let storage = StorageService()
                    term.snapImagePath = try storage.saveCrop(image: highlighted)
                }
            }

            try modelContext.save()
            onSave()
        } catch {
            print("Save failed: \(error)")
        }
    }

    private func highlightedImage(token: RecognizedToken) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)

        // Crop to the visible viewport from the import view
        let cropRect = CGRect(
            x: visibleRect.origin.x * imgW,
            y: visibleRect.origin.y * imgH,
            width: visibleRect.width * imgW,
            height: visibleRect.height * imgH
        ).intersection(CGRect(x: 0, y: 0, width: imgW, height: imgH))

        guard cropRect.width >= 50, cropRect.height >= 50,
              let cropped = cgImage.cropping(to: cropRect) else { return nil }

        let cropSize = CGSize(width: cropped.width, height: cropped.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: cropSize, format: format)

        return renderer.image { ctx in
            UIImage(cgImage: cropped).draw(at: .zero)

            // Highlight rect relative to the visible crop
            let rect = CGRect(
                x: token.boundingBox.origin.x - cropRect.origin.x,
                y: token.boundingBox.origin.y - cropRect.origin.y,
                width: token.boundingBox.width,
                height: token.boundingBox.height
            )
            let highlightColor = UIColor.systemYellow.withAlphaComponent(0.35)
            ctx.cgContext.setFillColor(highlightColor.cgColor)
            ctx.cgContext.fill(rect)
        }
    }
}
