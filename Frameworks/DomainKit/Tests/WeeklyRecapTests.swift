import XCTest
import DataKit
@testable import DomainKit

final class WeeklyRecapTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Los_Angeles")!; return c }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date { calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))! }
    private func attempt(_ at: Date, session: UUID = UUID(), correct: Bool = false, topic: String = "godan-te", id: UUID = UUID()) -> ExerciseAttempt {
        let snapshot = ExerciseSnapshot(id: "q", revision: 1, questionKind: .conjugation, prompt: "行く", acceptedAnswers: ["行って"], explanation: "Te form", metadata: .init(activityKind: "conjugation", topicID: topic, source: "Original beginner practice"))
        return .init(id: id, sessionID: session, snapshot: snapshot, response: .text(correct ? "行って" : "wrong"), outcome: correct ? .correct : .incorrect, submittedAt: at)
    }
    private func recap(_ attempts: [ExerciseAttempt], now: Date, topics: [String: ExerciseQuestionKind] = [:], events: [ReviewRatingEvent] = []) throws -> WeeklyRecap {
        try WeeklyRecapUseCase(loadAttempts: { attempts }, loadEvents: { events }, availableTopics: { topics }).execute(now: now, calendar: calendar)
    }
    func testLocalCalendarWindowsAcrossSpringAndFallDST() throws {
        for now in [date(2026, 3, 10), date(2026, 11, 3)] {
            let value = try recap([], now: now)
            XCTAssertEqual(value.currentInterval.start, calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)))
            XCTAssertEqual(value.priorInterval.start, calendar.date(byAdding: .day, value: -7, to: value.currentInterval.start))
            XCTAssertEqual(value.priorInterval.end, value.currentInterval.start)
            XCTAssertFalse(value.hasCurrentActivity)
            XCTAssertTrue(WeeklyRecap.historyDisclosure.contains("retained"))
        }
    }
    func testDuplicatesFutureAndRetriesDoNotInflateFirstAttempts() throws {
        let now = date(2026, 3, 10), session = UUID()
        let first = attempt(now.addingTimeInterval(-60), session: session)
        let value = try recap([first, first, attempt(now, session: session, correct: true), attempt(now.addingTimeInterval(1))], now: now)
        XCTAssertEqual(value.firstAttemptCounts[.conjugation], .init(submitted: 1, correct: 0))
        XCTAssertNil(value.comparableDelta[.conjugation])
        XCTAssertEqual(value.currentMistakes, 0)
    }
    func testRecurringTopicAndRetiredFocus() throws {
        let now = date(2026, 3, 10)
        let value = try recap([attempt(now), attempt(now.addingTimeInterval(-60)), attempt(now, topic: "retired-topic"), attempt(now, topic: "retired-topic")], now: now, topics: ["godan-te": .conjugation])
        XCTAssertEqual(value.recurringTopics.first?.topicID, "godan-te")
        XCTAssertFalse(value.availableFocusIDs.contains("retired-topic"))
        XCTAssertEqual(value.focus?.destination, .topic(kind: .conjugation, id: "godan-te"))
    }
    func testComparisonRequiresTenSamplesInBothPeriodsAndSameFingerprints() throws {
        let now = date(2026, 3, 10), prior = date(2026, 3, 1)
        let current = (0..<10).map { _ in attempt(now, correct: true) }
        let previous = (0..<10).map { _ in attempt(prior) }
        XCTAssertEqual(try recap(current + previous, now: now).comparableDelta[.conjugation]?.percentagePoints, 100)
        XCTAssertNil(try recap(current + Array(previous.dropLast()), now: now).comparableDelta[.conjugation])
        XCTAssertNil(try recap(current + (0..<10).map { _ in attempt(prior, topic: "changed") }, now: now).comparableDelta[.conjugation])
    }
    func testFirstRatingBeforeWindowDoesNotBecomeCurrentSuccess() throws {
        let now = date(2026, 3, 10), session = UUID(), saved = SavedStudyID(kind: .word, id: "deleted-item")
        let events = [ReviewRatingEvent(actionID: UUID(), sessionID: session, id: saved, again: true, submittedAt: date(2026, 3, 1)), ReviewRatingEvent(actionID: UUID(), sessionID: session, id: saved, again: false, submittedAt: now)]
        let value = try recap([], now: now, events: events)
        XCTAssertEqual(value.selfRatedCurrent.submitted, 0)
        XCTAssertEqual(value.selfRatedPrior, .init(submitted: 1, correct: 0))
    }
    func testUnknownMetadataCannotRecommendTopicAndLoaderErrorsPropagate() throws {
        let now = date(2026, 3, 10)
        var a = attempt(now); a.snapshot.metadata?.schemaVersion = 99
        var b = attempt(now); b.snapshot.metadata?.schemaVersion = 99
        XCTAssertTrue(try recap([a, b], now: now, topics: ["godan-te": .conjugation]).recurringTopics.isEmpty)
        enum Failure: Error { case injected }
        XCTAssertThrowsError(try WeeklyRecapUseCase(loadAttempts: { throw Failure.injected }, loadEvents: { [] }).execute(now: now, calendar: calendar))
    }
}
