import Foundation
import SwiftData

@Model
public final class Term {
    public var id: UUID
    public var createdAt: Date
    public var primary: String
    public var lemma: String
    public var pos: String
    @Attribute(originalName: "translationJa")
    public var translation: String
    public var definition: String = ""
    public var example: String = ""
    public var exampleTranslation: String = ""
    public var etymology: String = ""
    public var synonyms: String = ""
    public var antonyms: String = ""
    public var articleMode: Bool
    public var reviewBox: Int
    public var dueDate: Date

    @Relationship(deleteRule: .cascade, inverse: \Occurrence.term)
    public var occurrences: [Occurrence]

    @Relationship(deleteRule: .cascade, inverse: \Sense.term)
    public var senses: [Sense]

    public var folder: Folder?

    public var synonymsList: [String] {
        synonyms.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public var antonymsList: [String] {
        antonyms.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public init(
        primary: String,
        lemma: String,
        pos: POS,
        translation: String = "",
        definition: String = "",
        example: String = "",
        exampleTranslation: String = "",
        etymology: String = "",
        synonyms: String = "",
        antonyms: String = "",
        articleMode: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.primary = primary
        self.lemma = lemma
        self.pos = pos.rawValue
        self.translation = translation
        self.definition = definition
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.etymology = etymology
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.articleMode = articleMode
        self.reviewBox = 1
        self.dueDate = Date()
        self.occurrences = []
        self.senses = []
        self.folder = nil
    }

    public var posEnum: POS {
        get { POS(rawValue: pos) ?? .other }
        set { pos = newValue.rawValue }
    }
}
