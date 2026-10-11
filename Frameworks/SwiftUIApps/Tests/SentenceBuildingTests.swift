import XCTest
import DataKit
@testable import SwiftUIApps

final class SentenceBuildingTests: XCTestCase {
    private func question(_ id: String = "sentence") -> ExerciseSnapshot {
        ExerciseSnapshot(id: id, revision: 1, questionKind: .sentenceOrder, prompt: "Build the sentence", explanation: "Supplied example.", metadata: PracticeMetadata(activityKind: "sentenceOrder", topicID: "topic", tokens: [PracticeToken(id: "a", text: "の"), PracticeToken(id: "b", text: "の")], acceptedOrders: [["a", "b"]], source: "Original practice"))
    }
    private func persistence(record: @escaping (ExerciseAttempt, ExerciseCheckpoint) throws -> Void = { _, _ in }, save: @escaping (ExerciseCheckpoint) throws -> Void = { _ in }) -> ExercisePersistence {
        ExercisePersistence(attempts: { [] }, checkpoint: { _ in nil }, record: record, save: save, finish: { _, _ in })
    }
    func testChangedContentRequiresAtomicRestartBeforeEditing() {
        let old = question()
        let checkpoint = ExerciseCheckpoint(activityKey: "sentence-building:test", sessionID: UUID(), orderedSnapshots: [old], position: 0, updatedAt: Date())
        var changed = old; changed.revision = 2; changed.fingerprint = changed.computedFingerprint
        var writes: [ExerciseCheckpoint] = []
        var fail = true
        let storage = ExercisePersistence(attempts: { [] }, checkpoint: { _ in checkpoint }, record: { _, _ in XCTFail("Changed session must not record") }, save: { saved in
            writes.append(saved)
            if fail { throw ExerciseHistoryError.invalidRecord }
        }, finish: { _, _ in })
        let model = SentenceBuildingViewModel(snapshots: [changed], activityKey: checkpoint.activityKey, persistence: storage)
        model.send(.load); model.send(.append("a"))
        XCTAssertTrue(model.state.contentChanged); XCTAssertTrue(model.state.selectedIDs.isEmpty)
        model.send(.restart)
        XCTAssertTrue(model.state.contentChanged); XCTAssertFalse(model.canEdit)
        fail = false; model.send(.retry)
        XCTAssertEqual(writes.count, 2); XCTAssertEqual(writes[0], writes[1])
        XCTAssertEqual(writes[1].orderedSnapshots, [changed])
        XCTAssertNotEqual(writes[1].sessionID, checkpoint.sessionID)
        XCTAssertFalse(model.state.contentChanged); XCTAssertTrue(model.canEdit)
    }
    func testInitialSaveFailureDisablesEditingAndRetriesSameCheckpoint() {
        var saved: [ExerciseCheckpoint] = []
        var fail = true
        let model = SentenceBuildingViewModel(snapshots: [question()], activityKey: "sentence-building:test", persistence: persistence(save: { checkpoint in
            saved.append(checkpoint)
            if fail { throw ExerciseHistoryError.invalidRecord }
        }))
        model.send(.load); model.send(.append("a"))
        XCTAssertTrue(model.state.selectedIDs.isEmpty); XCTAssertFalse(model.canCheck)
        fail = false; model.send(.retry)
        XCTAssertEqual(saved.count, 2); XCTAssertEqual(saved[0], saved[1])
        model.send(.append("a")); XCTAssertEqual(model.state.selectedIDs, ["a"])
    }
    func testPartialDuplicateUndoClearAndNext() {
        let model = SentenceBuildingViewModel(snapshots: [question(), question("second")], activityKey: "sentence-building:test", persistence: persistence())
        model.send(.load); model.send(.append("a")); model.send(.append("a"))
        XCTAssertEqual(model.state.selectedIDs, ["a"]); XCTAssertFalse(model.canCheck)
        model.send(.check); XCTAssertFalse(model.state.isRevealed)
        model.send(.append("b")); model.send(.undo); XCTAssertEqual(model.state.selectedIDs, ["a"])
        model.send(.clear); XCTAssertTrue(model.state.selectedIDs.isEmpty)
        model.send(.append("b")); model.send(.append("a")); model.send(.check)
        XCTAssertEqual(model.state.outcome, .correct)
        model.send(.next); XCTAssertEqual(model.state.position, 1)
        XCTAssertTrue(model.state.selectedIDs.isEmpty); XCTAssertFalse(model.state.isRevealed)
    }
    func testRecordFailurePreservesExactResponseIdentityAndDate() {
        var submissions: [ExerciseAttempt] = []
        var fail = true
        let model = SentenceBuildingViewModel(snapshots: [question()], activityKey: "sentence-building:test", persistence: persistence(record: { attempt, _ in
            submissions.append(attempt)
            if fail { throw ExerciseHistoryError.invalidRecord }
        }))
        model.send(.load); model.send(.append("b")); model.send(.append("a")); model.send(.check)
        XCTAssertNotNil(model.state.errorMessage); XCTAssertFalse(model.state.isRevealed)
        model.send(.clear); model.send(.restart); XCTAssertEqual(model.state.selectedIDs, ["b", "a"])
        fail = false; model.send(.retry)
        XCTAssertEqual(submissions.count, 2); XCTAssertEqual(submissions[0], submissions[1])
        XCTAssertEqual(submissions[1].response, .orderedTokens(["b", "a"]))
        XCTAssertTrue(model.state.isRevealed); XCTAssertEqual(model.state.correctCount, 1)
        model.send(.check); XCTAssertEqual(submissions.count, 2)
    }
    func testResumeUsesHistoricalMetadataAndSubmittedOrder() {
        let historical = question()
        let session = UUID()
        let attempt = ExerciseAttempt(sessionID: session, snapshot: historical, response: .orderedTokens(["b", "a"]), outcome: .correct, submittedAt: Date())
        let checkpoint = ExerciseCheckpoint(activityKey: "mistakes:old", sessionID: session, orderedSnapshots: [historical], position: 0, revealedAttemptID: attempt.id, updatedAt: Date())
        let storage = ExercisePersistence(attempts: { [attempt] }, checkpoint: { _ in checkpoint }, record: { _, _ in }, save: { _ in }, finish: { _, _ in })
        let model = SentenceBuildingViewModel(snapshots: [historical], activityKey: checkpoint.activityKey, persistence: storage)
        model.send(.load)
        XCTAssertEqual(model.current, historical); XCTAssertEqual(model.state.selectedIDs, ["b", "a"])
        XCTAssertTrue(model.state.isRevealed); XCTAssertNil(model.state.errorMessage)
    }
    func testFailedNextRetainsRevealedOrderUntilRetry() {
        var fail = false
        let model = SentenceBuildingViewModel(snapshots: [question(), question("second")], activityKey: "sentence-building:test", persistence: persistence(save: { _ in if fail { throw ExerciseHistoryError.invalidRecord } }))
        model.send(.load); model.send(.append("a")); model.send(.append("b")); model.send(.check)
        fail = true; model.send(.next)
        XCTAssertEqual(model.state.position, 0); XCTAssertTrue(model.state.isRevealed)
        XCTAssertEqual(model.state.selectedIDs, ["a", "b"])
        fail = false; model.send(.retry)
        XCTAssertEqual(model.state.position, 1); XCTAssertTrue(model.state.selectedIDs.isEmpty)
    }
}
