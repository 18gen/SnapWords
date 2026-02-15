import Foundation
import UIKit

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

    public func imageCrop(
        for token: RecognizedToken,
        allTokens: [RecognizedToken],
        image: UIImage
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)

        let lineTokens = Dictionary(grouping: allTokens) { $0.lineId }
        let targetLineId = token.lineId

        var relevantTokens: [RecognizedToken] = []
        for id in [targetLineId - 1, targetLineId, targetLineId + 1] {
            if let tokens = lineTokens[id] {
                relevantTokens.append(contentsOf: tokens)
            }
        }

        guard !relevantTokens.isEmpty else { return nil }

        let minX = relevantTokens.map { $0.boundingBox.minX }.min()!
        let minY = relevantTokens.map { $0.boundingBox.minY }.min()!
        let maxX = relevantTokens.map { $0.boundingBox.maxX }.max()!
        let maxY = relevantTokens.map { $0.boundingBox.maxY }.max()!

        let padding: CGFloat = 20

        let cropRect = CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: min(imgW, maxX + padding) - max(0, minX - padding),
            height: min(imgH, maxY + padding) - max(0, minY - padding)
        )

        guard cropRect.width >= 50, cropRect.height >= 50 else { return nil }

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}
