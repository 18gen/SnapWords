import SwiftUI
import SwiftData
import LensCore

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppLocale.self) private var locale
    @State private var showDeleteConfirmation = false
    @State private var showDeletedAlert = false
    @State private var targetLanguage: String

    private let langSettings = LanguageSettings()

    init() {
        let settings = LanguageSettings()
        _targetLanguage = State(initialValue: settings.targetLanguage)
    }

    var body: some View {
        Form {
            Section(locale("settings.language")) {
                Picker(locale("settings.translate_language"), selection: $targetLanguage) {
                    ForEach(LanguageSettings.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .onChange(of: targetLanguage) { _, newValue in
                    langSettings.targetLanguage = newValue
                }
            }

            Section(locale("settings.data")) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(locale("settings.delete_all"), systemImage: "trash")
                }
            }

            Section(locale("settings.about")) {
                LabeledContent(locale("settings.version"), value: "1.0")
                LabeledContent(locale("settings.data_storage"), value: locale("settings.local_only"))
            }

            Section(locale("settings.export_import")) {
                Text(locale("settings.coming_soon"))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(locale("settings.title"))
        .confirmationDialog(
            locale("settings.delete_confirm_title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(locale("settings.delete_confirm_button"), role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text(locale("settings.delete_confirm_message"))
        }
        .alert(locale("settings.deleted"), isPresented: $showDeletedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(locale("settings.deleted_message"))
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: Folder.self)
            try modelContext.delete(model: Term.self)
            try modelContext.delete(model: Occurrence.self)
            try modelContext.delete(model: Sense.self)
            try StorageService().deleteAllData()
            try modelContext.save()
            // Re-create the Unfiled system folder
            FolderBootstrap.ensureUnfiledFolder(in: modelContext.container)
            showDeletedAlert = true
        } catch {
            print("Failed to delete data: \(error)")
        }
    }
}
