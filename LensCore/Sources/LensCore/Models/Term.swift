import Foundation
import SwiftData

@Model
public final class Term {
    public var id: UUID
    public var createdAt: Date
    public var primary: String
    public var lemma: String
    public var pos: String
    public var translationJa: String
    public var articleMode: Bool
    public var reviewBox: Int
    public var dueDate: Date

    @Relationship(deleteRule: .cascade, inverse: \Occurrence.term)
    public var occurrences: [Occurrence]

    @Relationship(deleteRule: .cascade, inverse: \Sense.term)
    public var senses: [Sense]

    public var folder: Folder?

    public init(
        primary: String,
        lemma: String,
        pos: POS,
        translationJa: String = "",
        articleMode: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.primary = primary
        self.lemma = lemma
        self.pos = pos.rawValue
        self.translationJa = translationJa
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
