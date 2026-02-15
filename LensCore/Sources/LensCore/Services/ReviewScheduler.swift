import Foundation

public struct ReviewScheduler: Sendable {
    public init() {}

    public func gotIt(now: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
    }

    public func again(now: Date = Date()) -> Date {
        now
    }

    public func isDue(_ term: Term, now: Date = Date()) -> Bool {
        term.dueDate <= now
    }
}
