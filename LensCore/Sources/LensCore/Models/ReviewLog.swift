import Foundation
import SwiftData

@Model
public final class ReviewLog {
    public var id: UUID
    public var date: Date

    public init() {
        self.id = UUID()
        self.date = Date()
    }
}
