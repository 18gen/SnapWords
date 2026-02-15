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
                        .foregroundStyle(.green)
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
        .toolbar {
            if folder != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale("review.close")) {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text(locale("review.due_count \(dueTerms.count)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                    Text(term.posEnum.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
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
                    .tint(.red)

                    Button {
                        markGotIt(term)
                    } label: {
                        Label(locale("review.got_it"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
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
}
