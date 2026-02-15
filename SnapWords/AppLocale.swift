import SwiftUI

@Observable
class AppLocale {
    var bundle: Bundle

    init() {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        self.bundle = Self.bundle(for: code)
    }

    func callAsFunction(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle)
    }

    private static func bundle(for code: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return .main
        }
        return b
    }
}
