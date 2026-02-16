import Foundation
import SwiftData

@Model
public final class ReviewLog {
    public var id: UUID
    public var date: Date
    public var term: Term?

    public init(term: Term? = nil) {
        self.id = UUID()
        self.date = Date()
        self.term = term
    }
}
