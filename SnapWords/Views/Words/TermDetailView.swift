import SwiftUI
import SwiftData
import LensCore

struct TermDetailView: View {
    @Bindable var term: Term
    @Environment(AppLocale.self) private var locale
    @State private var showFolderPicker = false
    @State private var showDictionary = false
    @State private var headerVisible = true

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

                Divider()
                    .padding(.horizontal)

                // MARK: - Class & Folder
                HStack(spacing: 0) {
                    // POS
                    VStack(spacing: 4) {
                        Text(locale("detail.pos"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(term.posEnum.displayName)
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

                Divider()
                    .padding(.horizontal)

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
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}
