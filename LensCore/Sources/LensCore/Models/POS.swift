import Foundation

public enum POS: String, Codable, CaseIterable, Sendable {
    case verb
    case adjective
    case noun
    case phrase
    case other

    public var displayName: String {
        switch self {
        case .verb: "Verb"
        case .adjective: "Adjective"
        case .noun: "Noun"
        case .phrase: "Phrase"
        case .other: "Other"
        }
    }
}
