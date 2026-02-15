import Testing
import Foundation
import CoreGraphics
@testable import LensCore

@Suite("ContextExtractor")
struct ContextExtractorTests {
    let extractor = ContextExtractor()

    private func makeToken(
        text: String, lineId: Int, x: CGFloat = 0
    ) -> RecognizedToken {
        RecognizedToken(
            text: text,
            normalizedText: text.lowercased(),
            boundingBox: CGRect(x: x, y: 0, width: 50, height: 20),
            lineId: lineId,
            confidence: 1.0
        )
    }

    @Test("context includes current line")
    func currentLine() {
        let tokens = [
            makeToken(text: "Hello", lineId: 0, x: 0),
            makeToken(text: "world", lineId: 0, x: 60),
        ]
        let result = extractor.context(for: tokens[0], tokens: tokens)
        #expect(result.contains("Hello"))
        #expect(result.contains("world"))
    }

    @Test("context includes adjacent lines")
    func adjacentLines() {
        let tokens = [
            makeToken(text: "Line1", lineId: 0),
            makeToken(text: "Line2", lineId: 1),
            makeToken(text: "Line3", lineId: 2),
        ]
        let result = extractor.context(for: tokens[1], tokens: tokens)
        #expect(result.contains("Line1"))
        #expect(result.contains("Line2"))
        #expect(result.contains("Line3"))
    }

    @Test("context excludes distant lines")
    func distantLines() {
        let tokens = [
            makeToken(text: "Far", lineId: 0),
            makeToken(text: "Target", lineId: 5),
        ]
        let result = extractor.context(for: tokens[1], tokens: tokens)
        #expect(result.contains("Target"))
        #expect(!result.contains("Far"))
    }

    @Test("context preserves word order within a line")
    func wordOrder() {
        let tokens = [
            makeToken(text: "The", lineId: 0, x: 0),
            makeToken(text: "quick", lineId: 0, x: 50),
            makeToken(text: "fox", lineId: 0, x: 100),
        ]
        let result = extractor.context(for: tokens[0], tokens: tokens)
        #expect(result == "The quick fox")
    }
}
