import SwiftUI
import SwiftData
import LensCore

struct TermDetailView: View {
    @Bindable var term: Term
    @Environment(AppLocale.self) private var locale
    @State private var showFolderPicker = false
    @State private var showDictionary = false
    @State private var headerVisible = true
    private let langSettings = LanguageSettings()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 6) {
                    Text(term.primary)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    if term.translation.isEmpty {
                        Button {
                            showDictionary = true
                        } label: {
                            Label(locale("word.look_up"), systemImage: "book.fill")
                                .font(.title3)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(term.translation)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                            Button {
                                showDictionary = true
                            } label: {
                                Image(systemName: "book")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .padding(.horizontal)
                .onScrollVisibilityChange { visible in
                    headerVisible = visible
                }

                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color(.separator))
                    .frame(height: 2)
                    .padding(.horizontal)

                // MARK: - Class & Folder
                HStack(spacing: 0) {
                    // POS
                    VStack(spacing: 4) {
                        Text(locale("detail.pos"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(term.posEnum.displayName(for: langSettings.nativeLanguage))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    // Folder
                    Button {
                        showFolderPicker = true
                    } label: {
                        VStack(spacing: 4) {
                            Text(locale("detail.folder"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            if let folder = term.folder {
                                HStack(spacing: 4) {
                                    Image(systemName: folder.iconName)
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: folder.colorHex))
                                    Text(folder.name)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                            } else {
                                Text("—")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 16)
                .padding(.horizontal)

                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color(.separator))
                    .frame(height: 2)
                    .padding(.horizontal)

                // MARK: - Example Card
                if !term.example.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(locale("detail.example"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        boldedExample(term.example, word: term.primary)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        if !term.exampleTranslation.isEmpty {
                            boldedExample(term.exampleTranslation, word: term.translation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 16)
                }

                // MARK: - Etymology Card
                if !term.etymology.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(locale("detail.etymology"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(term.etymology)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // MARK: - Synonyms & Antonyms
                if !term.synonymsList.isEmpty || !term.antonymsList.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !term.synonymsList.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(locale("detail.synonyms"))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                HStack(spacing: 8) {
                                    ForEach(term.synonymsList, id: \.self) { word in
                                        Text(word)
                                            .font(.callout)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        if !term.antonymsList.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(locale("detail.antonyms"))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                HStack(spacing: 8) {
                                    ForEach(term.antonymsList, id: \.self) { word in
                                        Text(word)
                                            .font(.callout)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray6))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 16)
                }

                // MARK: - Divider before Occurrences
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color(.separator))
                    .frame(height: 2)
                    .padding(.horizontal)
                    .padding(.top, 16)

                // MARK: - Occurrences
                let sorted = term.occurrences.sorted { $0.createdAt > $1.createdAt }
                if !sorted.isEmpty {
                    LazyVStack(spacing: 16) {
                        ForEach(sorted) { occurrence in
                            OccurrenceRow(occurrence: occurrence)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(term.primary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(term.primary)
                    .font(.headline)
                    .opacity(headerVisible ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: headerVisible)
            }
        }
        .sheet(isPresented: $showDictionary) {
            DictionaryView(term: term.primary)
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(term: term)
                .environment(locale)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func boldedExample(_ sentence: String, word: String) -> Text {
        guard !word.isEmpty else { return Text(sentence) }
        guard let range = sentence.range(of: word, options: .caseInsensitive) else { return Text(sentence) }
        let before = String(sentence[sentence.startIndex..<range.lowerBound])
        let match = String(sentence[range])
        let after = String(sentence[range.upperBound...])
        return Text(before) + Text(match).bold() + Text(after)
    }
}
