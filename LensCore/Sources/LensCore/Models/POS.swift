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

    public func displayName(for language: String) -> String {
        switch language {
        case "ja":
            switch self {
            case .verb: return "動詞"
            case .adjective: return "形容詞"
            case .noun: return "名詞"
            case .phrase: return "フレーズ"
            case .other: return "その他"
            }
        default:
            return displayName
        }
    }
}
