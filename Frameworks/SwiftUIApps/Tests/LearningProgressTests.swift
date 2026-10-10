import XCTest
import DataKit
import DomainKit
@testable import SwiftUIApps

final class LearningProgressTests: XCTestCase {
    func testDueCountLoadsIndependentlyOfHistoryRangeAndFailureCanRetry() {
        enum Failure: Error { case injected }
        var fails = true, calls = 0
        let model = LearningProgressViewModel(load: { ([], []) }, loadDue: { _ in
            calls += 1
            if fails { throw Failure.injected }
            return []
        })
        model.send(.load)
        XCTAssertNotNil(model.state.error)
        XCTAssertNil(model.state.summary)
        fails = false; model.send(.range(30))
        XCTAssertNil(model.state.error)
        XCTAssertEqual(model.state.dueCount, 0)
        XCTAssertNotNil(model.state.summary)
        XCTAssertEqual(calls, 2)
    }
    func testFirstResponseAndLocalDateRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let session = UUID(), id = SavedStudyID(kind: .word, id: "saved")
        let first = ReviewRatingEvent(actionID: UUID(), sessionID: session, id: id, again: true, submittedAt: now.addingTimeInterval(-10))
        let retry = ReviewRatingEvent(actionID: UUID(), sessionID: session, id: id, again: false, submittedAt: now)
        let value = LearningProgressSummary.calculate(attempts: [], events: [retry, first], days: 1, now: now, calendar: calendar)
        XCTAssertEqual(value.selfRatedTotal, 1)
        XCTAssertEqual(value.selfRatedGotIt, 0)
        XCTAssertNil(value.gradedAccuracy)
        XCTAssertEqual(value.practiceDays, 1)
        let earlier = ReviewRatingEvent(actionID: UUID(), sessionID: session, id: id, again: true, submittedAt: calendar.startOfDay(for: now).addingTimeInterval(-1))
        XCTAssertEqual(LearningProgressSummary.calculate(attempts: [], events: [earlier, retry], days: 1, now: now, calendar: calendar).selfRatedTotal, 0)
    }
    func testAccuracyAndMistakesRemainSeparateFromSelfRating() {
        let now = Date()
        let snapshot = ExerciseSnapshot(id: "q", revision: 1, questionKind: .choice, prompt: "Q", choices: ["A", "B"], correctIndex: 0, explanation: "A")
        let wrong = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .choice(1), outcome: .incorrect, submittedAt: now.addingTimeInterval(-5))
        let right = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .choice(0), outcome: .correct, submittedAt: now)
        let summary = LearningProgressSummary.calculate(attempts: [wrong, right], events: [], days: 7, now: now, calendar: .current)
        XCTAssertEqual(summary.gradedAccuracy, 0.5)
        XCTAssertEqual(summary.remainingMistakes, 0)
        XCTAssertEqual(summary.selfRatedTotal, 0)
    }
}
