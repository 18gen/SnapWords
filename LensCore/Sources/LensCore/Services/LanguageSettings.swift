import Foundation

public struct LanguageSettings: Sendable {
    private static let targetKey = "snapwords_target_language"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: StorageService.appGroupIdentifier)
    }

    public init() {}

    public var nativeLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    public var targetLanguage: String {
        get {
            if let saved = defaults?.string(forKey: Self.targetKey) {
                return saved
            }
            let native = nativeLanguage
            return Self.supportedLanguages.first { $0.code != native }?.code ?? "en"
        }
        nonmutating set { defaults?.set(newValue, forKey: Self.targetKey) }
    }

    public static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("ja", "Japanese"),
    ]
}
