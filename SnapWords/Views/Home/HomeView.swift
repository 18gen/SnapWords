import SwiftUI
import SwiftData
import LensCore

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppLocale.self) private var locale
    @Query(sort: \Term.createdAt, order: .reverse) private var allTerms: [Term]
    @Query(sort: \ReviewLog.date, order: .reverse) private var reviewLogs: [ReviewLog]

    @State private var searchText = ""
    @State private var navigateToReview = false

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var searchResults: [Term] {
        let query = searchText.lowercased()
        return allTerms.filter {
            $0.primary.lowercased().contains(query) ||
            $0.lemma.lowercased().contains(query) ||
            $0.translation.contains(query)
        }
    }

    private var dueCount: Int {
        let now = Date()
        return allTerms.filter { $0.dueDate <= now }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    searchResultsList
                } else {
                    homeContent
                }
            }
            .navigationTitle(locale("home.title"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: Text(locale("words.search")))
            .navigationDestination(for: Term.self) { term in
                TermDetailView(term: term)
                    .environment(locale)
            }
            .navigationDestination(isPresented: $navigateToReview) {
                ReviewView()
                    .environment(locale)
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Review button
                Button {
                    navigateToReview = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(locale("home.start_review"))
                                .font(.headline)
                            if dueCount > 0 {
                                Text(locale("home.due_count \(dueCount)"))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            } else {
                                Text(locale("home.no_due"))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.361, green: 0.722, blue: 0.478))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                
                // Heatmap
                ContributionHeatmapView(allTerms: allTerms, reviewLogs: reviewLogs)
                    .environment(locale)
                    .padding(.horizontal)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private var searchResultsList: some View {
        List {
            if searchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(searchResults) { term in
                    NavigationLink(value: term) {
                        FlatTermRow(term: term)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
