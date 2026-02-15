import Foundation
import SwiftData

@Model
public final class Sense {
    public var id: UUID
    public var createdAt: Date
    public var meaningJa: String
    public var note: String

    public var term: Term?

    public init(meaningJa: String, note: String = "") {
        self.id = UUID()
        self.createdAt = Date()
        self.meaningJa = meaningJa
        self.note = note
    }
}
