import XCTest
import DataKit
@testable import SwiftUIApps

final class ExerciseHistoryPresentationTests: XCTestCase {
    enum Failure: Error { case save }
    func testRetryPreservesDraftAttemptIdentityAndTimestamp() {
        var writes: [ExerciseAttempt] = []
        var fails = true
        let persistence = ExercisePersistence(attempts: { [] }, checkpoint: { _ in nil }, record: { attempt, _ in
            writes.append(attempt)
            if fails { throw Failure.save }
        }, save: { _ in }, finish: { _, _ in })
        let model = ExerciseSessionViewModel(exercises: [ExerciseCatalog.grammar[0]], activityKey: "test", persistence: persistence)
        model.send(.load); model.send(.choose(1))
        XCTAssertEqual(model.state.selectedIndex, 1)
        XCTAssertFalse(model.state.isRevealed)
        XCTAssertNotNil(model.state.errorMessage)
        model.send(.next)
        XCTAssertFalse(model.state.isComplete)
        fails = false; model.send(.retry)
        XCTAssertTrue(model.state.isRevealed)
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes[0], writes[1])
        model.send(.choose(0))
        XCTAssertEqual(writes.count, 2)
    }
    func testRestoresRevealedAnswerAndScoreWithoutRecordingAgain() {
        let question = ExerciseCatalog.grammar[0]
        let session = UUID()
        let attempt = ExerciseAttempt(sessionID: session, snapshot: question.snapshot, response: .choice(question.correctIndex), outcome: .correct, submittedAt: Date())
        let saved = ExerciseCheckpoint(activityKey: "test", sessionID: session, orderedSnapshots: [question.snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: Date())
        var recorded = false
        let persistence = ExercisePersistence(attempts: { [attempt] }, checkpoint: { _ in saved }, record: { _, _ in recorded = true }, save: { _ in }, finish: { _, _ in })
        let model = ExerciseSessionViewModel(exercises: [question], activityKey: "test", persistence: persistence)
        model.send(.load)
        XCTAssertTrue(model.state.isRevealed)
        XCTAssertEqual(model.state.correctCount, 1)
        model.send(.choose(0))
        XCTAssertFalse(recorded)
    }
    func testChangedContentRequiresExplicitRestartAndFailedRestartRetainsOldSession() {
        let original = ExerciseCatalog.grammar[0]
        let changed = PracticeExercise(id: original.id, kind: .choice, prompt: "Changed", choices: original.choices, correctIndex: original.correctIndex, explanation: original.explanation)
        let saved = ExerciseCheckpoint(activityKey: "test", sessionID: UUID(), orderedSnapshots: [original.snapshot], position: 0, updatedAt: Date())
        var replacement: ExerciseCheckpoint?
        var fails = true
        let persistence = ExercisePersistence(attempts: { [] }, checkpoint: { _ in saved }, record: { _, _ in XCTFail() }, save: { value in
            if fails { throw Failure.save }; replacement = value
        }, finish: { _, _ in })
        let model = ExerciseSessionViewModel(exercises: [changed], activityKey: "test", persistence: persistence)
        model.send(.load)
        XCTAssertTrue(model.state.contentChanged)
        XCTAssertNil(replacement)
        model.send(.restart)
        XCTAssertTrue(model.state.contentChanged)
        fails = false; model.send(.retry)
        XCTAssertFalse(model.state.contentChanged)
        XCTAssertNotEqual(replacement?.sessionID, saved.sessionID)
        XCTAssertEqual(replacement?.orderedSnapshots, [changed.snapshot])
    }
    func testNextSaveFailureKeepsFeedbackAndPosition() {
        var fails = false
        let persistence = ExercisePersistence(attempts: { [] }, checkpoint: { _ in nil }, record: { _, _ in }, save: { _ in if fails { throw Failure.save } }, finish: { _, _ in })
        let model = ExerciseSessionViewModel(exercises: Array(ExerciseCatalog.grammar.prefix(2)), activityKey: "test", persistence: persistence)
        model.send(.load); model.send(.choose(0)); fails = true; model.send(.next)
        XCTAssertEqual(model.state.position, 0)
        XCTAssertTrue(model.state.isRevealed)
        fails = false; model.send(.retry)
        XCTAssertEqual(model.state.position, 1)
        XCTAssertFalse(model.state.isRevealed)
    }
    func testHistoricalSnapshotRetainsRevisionAndFingerprint() {
        let snapshot = ExerciseSnapshot(id: "retired", revision: 7, questionKind: .choice, prompt: "Old question", choices: ["A", "B"], correctIndex: 0, explanation: "Original explanation")
        XCTAssertEqual(PracticeExercise(snapshot: snapshot).snapshot, snapshot)
    }
    func testHistoryLatestMistakeAndRetry() {
        let question = ExerciseCatalog.grammar[0]
        let session = UUID()
        let wrong = ExerciseAttempt(sessionID: session, snapshot: question.snapshot, response: .choice(1), outcome: .incorrect, submittedAt: Date(timeIntervalSince1970: 1))
        let correct = ExerciseAttempt(sessionID: session, snapshot: question.snapshot, response: .choice(0), outcome: .correct, submittedAt: Date(timeIntervalSince1970: 2))
        var fails = true
        let model = ExerciseHistoryViewModel(load: { if fails { throw Failure.save }; return [wrong, correct] })
        model.send(.load)
        XCTAssertNotNil(model.state.errorMessage)
        fails = false; model.send(.load)
        XCTAssertEqual(model.state.attempts.count, 2)
        XCTAssertTrue(model.state.mistakes.isEmpty)
        XCTAssertNil(model.state.errorMessage)
    }
}
