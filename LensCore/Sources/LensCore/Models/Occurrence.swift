import Foundation
import SwiftData

@Model
public final class Occurrence {
    public var id: UUID
    public var createdAt: Date
    public var rawText: String
    public var context: String
    public var screenshotPath: String
    public var cropPath: String?
    public var sourceLabel: String?

    public var term: Term?

    public init(
        rawText: String,
        context: String,
        screenshotPath: String,
        cropPath: String? = nil,
        sourceLabel: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.rawText = rawText
        self.context = context
        self.screenshotPath = screenshotPath
        self.cropPath = cropPath
        self.sourceLabel = sourceLabel
    }
}
