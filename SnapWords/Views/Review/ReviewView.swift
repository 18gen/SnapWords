import SwiftUI
import SwiftData
import LensCore

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocale.self) private var locale
    @Query(sort: \Term.dueDate) private var allTerms: [Term]
    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var showDictionary = false

    private let scheduler = ReviewScheduler()
    private let langSettings = LanguageSettings()
    private let folder: Folder?

    init(folder: Folder? = nil) {
        self.folder = folder
    }

    private var dueTerms: [Term] {
        let now = Date()
        let source: [Term] = folder?.allTermsRecursive ?? allTerms
        return source.filter { $0.dueDate <= now }
    }

    var body: some View {
        VStack {
            if dueTerms.isEmpty {

                ContentUnavailableView(
                    locale("review.all_done.title"),
                    systemImage: "checkmark.circle",
                    description: Text(locale("review.all_done.description"))
                )
            } else if currentIndex < dueTerms.count {
                reviewCard(for: dueTerms[currentIndex])
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "party.popper")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(red: 0.361, green: 0.722, blue: 0.478)) // #5CB87A sage
                    Text(locale("review.session_complete"))
                        .font(.title2)
                    Text(locale("review.reviewed_count \(dueTerms.count)"))
                        .foregroundStyle(.secondary)
                    Button(locale("review.start_over")) {
                        currentIndex = 0
                        showAnswer = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle(folder?.name ?? locale("review.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if folder != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale("review.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewCard(for term: Term) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(term.primary)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if showAnswer {
                VStack(spacing: 12) {
                    Divider()

                    if term.translation.isEmpty {
                        Button {
                            showDictionary = true
                        } label: {
                            Label(locale("word.look_up"), systemImage: "book.fill")
                                .font(.title2)
                        }
                        .padding(.horizontal)
                    } else {
                        Text(term.translation)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if !term.etymology.isEmpty {
                        Text(term.etymology)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if !term.example.isEmpty {
                        boldedExample(term.example, word: term.primary)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if !term.exampleTranslation.isEmpty {
                            boldedExample(term.exampleTranslation, word: term.translation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }

                    Text(term.posEnum.displayName(for: langSettings.nativeLanguage))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(posColor(for: term.posEnum))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(posColor(for: term.posEnum).opacity(0.12))
                        .clipShape(Capsule())

                    if !term.synonymsList.isEmpty {
                        VStack(spacing: 4) {
                            Text(locale("detail.synonyms"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            HStack(spacing: 6) {
                                ForEach(term.synonymsList, id: \.self) { word in
                                    Text(word)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    if !term.antonymsList.isEmpty {
                        VStack(spacing: 4) {
                            Text(locale("detail.antonyms"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            HStack(spacing: 6) {
                                ForEach(term.antonymsList, id: \.self) { word in
                                    Text(word)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            if showAnswer {
                HStack(spacing: 24) {
                    Button {
                        markAgain(term)
                    } label: {
                        Label(locale("review.again"), systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(red: 0.878, green: 0.486, blue: 0.424)) // #E07C6C muted coral

                    Button {
                        markGotIt(term)
                    } label: {
                        Label(locale("review.got_it"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.361, green: 0.722, blue: 0.478)) // #5CB87A muted sage
                }
                .padding(.horizontal)
            } else {
                Button {
                    withAnimation {
                        showAnswer = true
                    }
                } label: {
                    Text(locale("review.show_answer"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 32)
        .sheet(isPresented: $showDictionary) {
            if currentIndex < dueTerms.count {
                DictionaryView(term: dueTerms[currentIndex].primary)
            }
        }
    }

    private func markGotIt(_ term: Term) {
        term.dueDate = scheduler.gotIt()
        advance()
    }

    private func markAgain(_ term: Term) {
        term.dueDate = scheduler.again()
        advance()
    }

    private func advance() {
        showAnswer = false
        currentIndex += 1
    }

    private func posColor(for pos: POS) -> Color {
        switch pos {
        case .noun: Color(red: 0.356, green: 0.553, blue: 0.937)
        case .verb: Color(red: 0.878, green: 0.533, blue: 0.302)
        case .adjective: Color(red: 0.361, green: 0.722, blue: 0.478)
        case .phrase: Color(red: 0.608, green: 0.494, blue: 0.784)
        case .other: .gray
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
