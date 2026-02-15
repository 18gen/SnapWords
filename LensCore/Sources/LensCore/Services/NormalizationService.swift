import Foundation

public struct NormalizationService: Sendable {
    public init() {}

    public func makePrimary(
        raw: String,
        lemma: String,
        pos: POS,
        articleMode: Bool = false,
        phraseText: String? = nil
    ) -> String {
        let baseLemma = lemma.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)

        switch pos {
        case .verb:
            if let phrase = phraseText, !phrase.isEmpty {
                return "to " + phrase.lowercased()
            }
            return "to " + baseLemma

        case .adjective:
            return "to be " + baseLemma

        case .noun:
            if articleMode {
                let article = Self.chooseArticle(for: baseLemma)
                return article + " " + baseLemma
            }
            return baseLemma

        case .phrase:
            if let phrase = phraseText, !phrase.isEmpty {
                return phrase.lowercased()
            }
            return baseLemma

        case .other:
            return baseLemma
        }
    }

    public static func chooseArticle(for word: String) -> String {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        guard let first = word.lowercased().first else { return "a" }
        return vowels.contains(first) ? "an" : "a"
    }
}
