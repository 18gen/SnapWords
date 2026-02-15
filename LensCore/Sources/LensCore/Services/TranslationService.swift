import Foundation

// Translation is handled via SwiftUI's .translationTask modifier in the UI layer.
// This file provides a lightweight type for future service-level translation if needed.

public struct TranslationRequest: Sendable {
    public let sourceText: String
    public init(sourceText: String) {
        self.sourceText = sourceText
    }
}
