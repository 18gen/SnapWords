import Foundation
import NaturalLanguage

public struct POSGuess: Sendable {
    public let pos: POS
    public let lemma: String

    public init(pos: POS, lemma: String) {
        self.pos = pos
        self.lemma = lemma
    }
}

public struct POSService: Sendable {
    public init() {}

    public func guess(for text: String) -> POSGuess {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        let cleanText = text.trimmingCharacters(in: .punctuationCharacters)
        tagger.string = cleanText

        var detectedPOS: POS = .other
        var detectedLemma = cleanText.lowercased()

        let range = cleanText.startIndex..<cleanText.endIndex

        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, tokenRange in
            if let tag {
                switch tag {
                case .verb:
                    detectedPOS = .verb
                case .adjective:
                    detectedPOS = .adjective
                case .noun:
                    detectedPOS = .noun
                case .preposition, .conjunction:
                    detectedPOS = .phrase
                default:
                    detectedPOS = .other
                }
            }
            return false
        }

        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, tokenRange in
            if let tag {
                detectedLemma = tag.rawValue.lowercased()
            }
            return false
        }

        return POSGuess(pos: detectedPOS, lemma: detectedLemma)
    }
}
