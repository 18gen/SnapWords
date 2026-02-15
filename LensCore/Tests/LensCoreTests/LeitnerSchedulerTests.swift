import Testing
import Foundation
@testable import LensCore

@Suite("ReviewScheduler")
struct ReviewSchedulerTests {
    let scheduler = ReviewScheduler()
    let now = Date()

    @Test("gotIt returns due date 1 day from now")
    func gotItAddsOneDay() {
        let dueDate = scheduler.gotIt(now: now)
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        #expect(Calendar.current.isDate(dueDate, inSameDayAs: expected))
    }

    @Test("again returns current time")
    func againReturnsNow() {
        let dueDate = scheduler.again(now: now)
        #expect(dueDate == now)
    }
}
