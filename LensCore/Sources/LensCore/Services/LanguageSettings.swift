import Foundation

public struct LanguageSettings: Sendable {
    private static let sourceKey = "snapwords_source_language"
    private static let targetKey = "snapwords_target_language"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: StorageService.appGroupIdentifier)
    }

    public init() {}

    public var sourceLanguage: String {
        get { defaults?.string(forKey: Self.sourceKey) ?? "en" }
        nonmutating set { defaults?.set(newValue, forKey: Self.sourceKey) }
    }

    public var targetLanguage: String {
        get { defaults?.string(forKey: Self.targetKey) ?? "ja" }
        nonmutating set { defaults?.set(newValue, forKey: Self.targetKey) }
    }

    public static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("ja", "Japanese"),
    ]
}
