import Foundation
import CoreGraphics

public struct RecognizedToken: Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let normalizedText: String
    public let boundingBox: CGRect
    public let lineId: Int
    public let confidence: Float

    public init(
        id: UUID = UUID(),
        text: String,
        normalizedText: String,
        boundingBox: CGRect,
        lineId: Int,
        confidence: Float
    ) {
        self.id = id
        self.text = text
        self.normalizedText = normalizedText
        self.boundingBox = boundingBox
        self.lineId = lineId
        self.confidence = confidence
    }
}
