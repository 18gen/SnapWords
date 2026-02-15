import Foundation

public struct ContextExtractor: Sendable {
    public init() {}

    public func context(for token: RecognizedToken, tokens: [RecognizedToken]) -> String {
        let lineTokens = Dictionary(grouping: tokens) { $0.lineId }
        let targetLineId = token.lineId

        var contextLines: [Int: [RecognizedToken]] = [:]

        if let prev = lineTokens[targetLineId - 1] {
            contextLines[targetLineId - 1] = prev
        }
        if let current = lineTokens[targetLineId] {
            contextLines[targetLineId] = current
        }
        if let next = lineTokens[targetLineId + 1] {
            contextLines[targetLineId + 1] = next
        }

        let sortedLineIds = contextLines.keys.sorted()
        var lines: [String] = []

        for lineId in sortedLineIds {
            guard let tokens = contextLines[lineId] else { continue }
            let sorted = tokens.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
            let lineText = sorted.map(\.text).joined(separator: " ")
            lines.append(lineText)
        }

        return lines.joined(separator: "\n")
    }
}
