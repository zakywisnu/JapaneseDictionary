import XCTest
import Foundation
import DataKit
@testable import DomainKit

final class DailyStudyGoalTests: XCTestCase {
    func testSummaryCountsCapturedDayAndOffKeepsHistory() throws {
        let repo = GoalStub()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1800000000)
        let completion = DefaultPracticeCompletionUseCase(repository: repo, calendar: calendar)
        try completion.execute(id: .init(kind: .word, id: "a"), now: now)
        let get = DefaultGetDailyStudyGoalUseCase(repository: repo, calendar: calendar)
        XCTAssertEqual(try get.execute(now: now).completedCount, 1)
        XCTAssertTrue(try get.execute(now: now).isReached)
        try DefaultSetDailyStudyGoalUseCase(repository: repo).execute(target: nil)
        XCTAssertNil(try get.execute(now: now).target)
        XCTAssertFalse(try get.execute(now: now).isReached)
        XCTAssertEqual(try get.execute(now: now).completedCount, 1)
        XCTAssertEqual(try get.execute(now: now.addingTimeInterval(86400)).completedCount, 0)
    }
    private final class GoalStub: DailyGoalRepository {
        var goal: Int? = 1
        var history: [PracticeActivity] = []
        func target() throws -> Int? { goal }
        func setTarget(_ target: Int?) throws { goal = target }
        func activities(dayKey: String) throws -> [PracticeActivity] { history.filter { $0.dayKey == dayKey } }
        func record(_ activity: PracticeActivity) throws { history.append(activity) }
    }
}
