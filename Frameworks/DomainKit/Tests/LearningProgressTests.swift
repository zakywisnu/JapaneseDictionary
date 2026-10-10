import XCTest
import DataKit
@testable import DomainKit

final class LearningProgressTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar { var result = Calendar(identifier: .gregorian); result.timeZone = TimeZone(secondsFromGMT: 7 * 3_600)!; return result }
    private func attempt(_ kind: ExerciseQuestionKind = .choice, correct: Bool = true, id: String = "q", at: Date? = nil) -> ExerciseAttempt {
        let snapshot: ExerciseSnapshot
        let response: ExerciseResponse
        let outcome: ExerciseOutcome
        switch kind {
        case .choice:
            snapshot = .init(id: id, revision: 1, questionKind: kind, prompt: "Q", choices: ["A", "B"], correctIndex: 0, explanation: "A")
            response = .choice(correct ? 0 : 1); outcome = correct ? .correct : .incorrect
        case .meaningSelfRated:
            snapshot = .init(id: id, revision: 1, questionKind: kind, prompt: "森", explanation: "Forest")
            response = .selfRating(correct); outcome = .selfRated
        default:
            snapshot = .init(id: id, revision: 1, questionKind: kind, prompt: "森", acceptedAnswers: ["もり"], explanation: "Reading")
            response = .text(correct ? "もり" : "wrong"); outcome = correct ? .correct : .incorrect
        }
        return .init(sessionID: UUID(), snapshot: snapshot, response: response, outcome: outcome, submittedAt: at ?? now)
    }
    func testRemainingMistakesAreSeparatedByKindAndCorrectRetryClearsOne() {
        let now = Date()
        let choice = ExerciseSnapshot(id: "grammar", revision: 1, questionKind: .choice, prompt: "Q", choices: ["A", "B"], correctIndex: 0, explanation: "A")
        let typed = ExerciseSnapshot(id: "typed", revision: 1, questionKind: .kanaReading, prompt: "猫", acceptedAnswers: ["ねこ"], explanation: "ねこ")
        let listening = ExerciseSnapshot(id: "listening", revision: 1, questionKind: .listeningReading, prompt: "猫", acceptedAnswers: ["ねこ"], explanation: "ねこ")
        var attempts = [ExerciseAttempt(sessionID: UUID(), snapshot: choice, response: .choice(1), outcome: .incorrect, submittedAt: now), ExerciseAttempt(sessionID: UUID(), snapshot: typed, response: .text("いぬ"), outcome: .incorrect, submittedAt: now), ExerciseAttempt(sessionID: UUID(), snapshot: listening, response: .text("いぬ"), outcome: .incorrect, submittedAt: now)]
        var summary = LearningProgressSummary.calculate(attempts: attempts, events: [], days: 1, now: now, calendar: .current)
        XCTAssertEqual(summary.remainingMistakesByKind, [.choice: 1, .kanaReading: 1, .listeningReading: 1])
        attempts.append(.init(sessionID: UUID(), snapshot: typed, response: .text("ねこ"), outcome: .correct, submittedAt: now.addingTimeInterval(1)))
        summary = .calculate(attempts: attempts, events: [], days: 1, now: now.addingTimeInterval(2), calendar: .current)
        XCTAssertNil(summary.remainingMistakesByKind[.kanaReading])
        XCTAssertEqual(summary.remainingMistakes, 2)
    }
    func testEmptyAndDuplicateUUIDAccuracyWithRetiredContent() {
        let empty = LearningProgressSummary.calculate(attempts: [], events: [], days: 7, now: now, calendar: calendar)
        XCTAssertNil(empty.gradedAccuracy); XCTAssertNil(empty.choice.accuracy); XCTAssertNil(empty.reviewRecordedSince)
        let wrong = attempt(correct: false, id: "retired"), right = attempt(id: "retired"), another = attempt(id: "retired")
        let summary = LearningProgressSummary.calculate(attempts: [wrong, right, right, another], events: [], days: 7, now: now, calendar: calendar)
        XCTAssertEqual(summary.gradedTotal, 3); XCTAssertEqual(summary.gradedCorrect, 2)
        XCTAssertEqual(summary.gradedAccuracy!, 2.0 / 3.0, accuracy: 0.00001)
        XCTAssertEqual(summary.choice.submitted, 3); XCTAssertEqual(summary.distinctAttemptedContent, 1)
    }
    func testEachModeAndMeaningRemainSeparate() {
        let values = [attempt(.choice), attempt(.kanaReading), attempt(.romanization, correct: false), attempt(.listeningReading), attempt(.meaningSelfRated), attempt(.meaningSelfRated, correct: false)]
        let summary = LearningProgressSummary.calculate(attempts: values, events: [], days: 1, now: now, calendar: calendar)
        XCTAssertEqual(summary.gradedTotal, 4); XCTAssertEqual(summary.gradedCorrect, 3)
        XCTAssertEqual(summary.choice.correct, 1); XCTAssertEqual(summary.kanaReading.correct, 1)
        XCTAssertEqual(summary.romanization.correct, 0); XCTAssertEqual(summary.listeningReading.correct, 1)
        XCTAssertEqual(summary.meaningSelfRatedSubmitted, 2); XCTAssertEqual(summary.meaningSelfRatedRemembered, 1)
        XCTAssertEqual(summary.selfRatedTotal, 0)
    }
    func testFirstReviewResponseAcrossWindowAndDuplicateActions() {
        let session = UUID(), id = SavedStudyID(kind: .word, id: "saved")
        let firstDate = calendar.startOfDay(for: now).addingTimeInterval(-1)
        let first = ReviewRatingEvent(actionID: UUID(), sessionID: session, id: id, again: true, submittedAt: firstDate)
        let repeatRating = ReviewRatingEvent(actionID: UUID(), sessionID: session, id: id, again: false, submittedAt: now)
        let today = LearningProgressSummary.calculate(attempts: [], events: [first, repeatRating, repeatRating], days: 1, now: now, calendar: calendar)
        XCTAssertEqual(today.selfRatedTotal, 0); XCTAssertEqual(today.practiceDays, 1)
        XCTAssertEqual(today.reviewRecordedSince, firstDate)
        let week = LearningProgressSummary.calculate(attempts: [], events: [repeatRating, first, first], days: 7, now: now, calendar: calendar)
        XCTAssertEqual(week.selfRatedTotal, 1); XCTAssertEqual(week.selfRatedGotIt, 0)
    }
    func testLocalMidnightTimezoneFutureAndSeparateDailyGoalItems() {
        let before = calendar.startOfDay(for: now).addingTimeInterval(-1)
        let activity = PracticeActivity(id: .init(kind: .word, id: "saved"), completedAt: now, calendar: calendar)
        let today = LearningProgressSummary.calculate(attempts: [attempt(at: before), attempt(at: now.addingTimeInterval(1))], events: [], days: 1, now: now, calendar: calendar, activities: [activity, activity])
        XCTAssertEqual(today.gradedTotal, 0); XCTAssertEqual(today.practiceDays, 1); XCTAssertEqual(today.distinctSavedItemsPracticed, 1)
        XCTAssertEqual(today.rangeStart, calendar.startOfDay(for: now))
        XCTAssertEqual(today.timeZoneIdentifier, calendar.timeZone.identifier)
        XCTAssertTrue(today.rangeCaption.contains(calendar.timeZone.identifier))
        var west = calendar; west.timeZone = TimeZone(secondsFromGMT: -7 * 3_600)!
        let shifted = LearningProgressSummary.calculate(attempts: [attempt(at: before)], events: [], days: 1, now: now, calendar: west)
        XCTAssertEqual(shifted.rangeStart, west.startOfDay(for: now))
        XCTAssertNotEqual(shifted.rangeStart, today.rangeStart)
    }
    func testDSTUsesCalendarDaysRatherThanFixedSeconds() {
        var local = Calendar(identifier: .gregorian); local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = local.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 12))!
        let result = LearningProgressSummary.calculate(attempts: [], events: [], days: 7, now: date, calendar: local)
        XCTAssertEqual(result.rangeStart, local.date(from: DateComponents(year: 2026, month: 3, day: 3))!)
        XCTAssertNotEqual(result.rangeStart, local.startOfDay(for: date).addingTimeInterval(-6 * 86_400))
    }
    func testPathStatusCurrentRevisionAndHistoricalCompletion() {
        let steps = (0..<5).map { LearningPathStep(id: "step\($0)", revision: 2, title: "Step \($0)", activityKey: "practice", requiredContentIDs: ["q\($0)"]) }
        let progress = LearningPathProgress(pathID: "starter", currentStepID: "step0", completedRevisions: [.init(stepID: "step1", revision: 2, completedAt: now), .init(stepID: "step4", revision: 1, completedAt: now)], skippedSteps: [.init(stepID: "step2", skippedAt: now)], updatedAt: now)
        var attempted = attempt(id: "q3"); attempted.snapshot.revision = 2
        let result = LearningProgressSummary.calculate(attempts: [attempted], events: [], days: 7, now: now, calendar: calendar, pathProgress: progress, pathSteps: steps)
        XCTAssertEqual(result.pathStepStatuses.map(\.status), [.current, .completed, .skipped, .attempted, .notStarted])
    }
}
