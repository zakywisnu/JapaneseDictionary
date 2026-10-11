import XCTest
import DataKit
@testable import SwiftUIApps

@MainActor final class ListeningComprehensionTests: XCTestCase {
    enum Failure: Error { case save }
    private func questions() -> [ExerciseSnapshot] {
        (0..<2).map { index in
            .init(id: "listen-\(index)", revision: 1, questionKind: .listeningComprehension, prompt: "When?", choices: ["Morning", "Evening"], correctIndex: 0, explanation: "あさ says morning", metadata: .init(activityKind: "listeningComprehension", topicID: "morning", stimulus: "朝、学校へ行きます。", suppliedReading: "あさ、がっこうへいきます。", translation: "I go to school in the morning.", source: "Original"))
        }
    }
    private final class Memory {
        var saved: ExerciseCheckpoint?
        var attempts: [ExerciseAttempt] = []
        var writes: [ExerciseAttempt] = []
        var checkpointWrites: [ExerciseCheckpoint] = []
        var failSave = false
        var failRecord = false
        var persistence: ExercisePersistence {
            .init(attempts: { self.attempts }, checkpoint: { _ in self.saved }, record: { attempt, checkpoint in
                self.writes.append(attempt)
                if self.failRecord { throw Failure.save }
                try ExerciseHistoryValidator.validateAttempt(attempt)
                try ExerciseHistoryValidator.validateCheckpoint(checkpoint, attempts: self.attempts + [attempt])
                self.attempts.append(attempt); self.saved = checkpoint
            }, save: { checkpoint in
                self.checkpointWrites.append(checkpoint)
                if self.failSave { throw Failure.save }
                try ExerciseHistoryValidator.validateCheckpoint(checkpoint, attempts: self.attempts)
                self.saved = checkpoint
            }, finish: { _, _ in self.saved = nil })
        }
    }
    private func model(_ memory: Memory, _ engine: ListeningEngine) -> ListeningComprehensionViewModel {
        .init(snapshots: questions(), activityKey: "comprehension:test", persistence: memory.persistence, pronunciation: .init(engine: engine))
    }
    private func play(_ model: ListeningComprehensionViewModel, _ engine: ListeningEngine) {
        model.send(.play); engine.complete(); model.send(.playbackChanged)
    }
    func testNoAutoplayAndPlaybackMustSucceedBeforeScoring() {
        let memory = Memory(), engine = ListeningEngine(); let value = model(memory, engine)
        value.send(.load); value.send(.choose(0)); value.send(.check)
        XCTAssertEqual(engine.calls, 0); XCTAssertTrue(memory.attempts.isEmpty); XCTAssertFalse(value.state.transcriptVisible)
        engine.available = false; value.send(.play); value.send(.check)
        XCTAssertTrue(memory.attempts.isEmpty); XCTAssertNotNil(value.playbackError)
        engine.available = true; play(value, engine); value.send(.check)
        XCTAssertEqual(memory.attempts.count, 1); XCTAssertEqual(memory.attempts[0].snapshot.questionKind, .listeningComprehension)
        XCTAssertEqual(value.state.checked, 1); XCTAssertFalse(value.state.transcriptVisible)
    }
    func testCancelledPlaybackCannotUnlockCheckWithLateCompletion() {
        let memory = Memory(), engine = ListeningEngine(); let value = model(memory, engine)
        value.send(.load); value.send(.play); value.send(.choose(0)); value.send(.stop)
        engine.complete(); value.send(.playbackChanged); value.send(.check)
        XCTAssertFalse(value.state.heardPlayback); XCTAssertTrue(memory.attempts.isEmpty)
    }
    func testFailedAnswerRetryPreservesIdentityDateAndChoice() {
        let memory = Memory(), engine = ListeningEngine(); let value = model(memory, engine)
        value.send(.load); play(value, engine); value.send(.choose(1)); memory.failRecord = true; value.send(.check)
        XCTAssertNotNil(value.state.error); XCTAssertFalse(value.state.answered)
        value.send(.choose(0)); value.send(.restart); XCTAssertEqual(value.state.selected, 1)
        memory.failRecord = false; value.send(.retry)
        XCTAssertEqual(memory.writes.count, 2); XCTAssertEqual(memory.writes[0], memory.writes[1])
        XCTAssertEqual(memory.attempts.count, 1); XCTAssertEqual(value.state.correct, false)
    }
    func testTranscriptRevealIsAtomicAndAssistanceSurvivesResume() {
        let memory = Memory(), engine = ListeningEngine(); let value = model(memory, engine)
        value.send(.load); memory.failSave = true; value.send(.revealTranscript)
        XCTAssertFalse(value.state.transcriptVisible); XCTAssertFalse(value.state.assisted)
        XCTAssertFalse(memory.saved!.orderedSnapshots[0].metadata!.assisted)
        memory.failSave = false; value.send(.retry)
        XCTAssertTrue(value.state.transcriptVisible); XCTAssertTrue(value.state.assisted)
        let restored = model(memory, ListeningEngine()); restored.send(.load)
        XCTAssertTrue(restored.state.assisted); XCTAssertFalse(restored.state.heardPlayback)
        play(value, engine); value.send(.choose(0)); value.send(.check); value.send(.next)
        XCTAssertEqual(value.state.position, 1); XCTAssertTrue(value.state.assisted); XCTAssertTrue(memory.attempts.isEmpty)
        let later = model(memory, ListeningEngine()); later.send(.load)
        XCTAssertTrue(later.state.assisted); XCTAssertTrue(later.state.transcriptVisible); XCTAssertFalse(later.canCheck)
    }
    func testRevealAfterGradingPreservesAttemptAndAssistsRemainingQuestion() throws {
        let memory = Memory(), engine = ListeningEngine(); let value = model(memory, engine)
        value.send(.load); play(value, engine); value.send(.choose(0)); value.send(.check)
        let first = try XCTUnwrap(memory.attempts.first)
        value.send(.revealTranscript)
        XCTAssertEqual(memory.saved?.orderedSnapshots[0], first.snapshot)
        XCTAssertEqual(memory.saved?.revealedAttemptID, first.id)
        XCTAssertTrue(memory.saved!.orderedSnapshots[1].metadata!.assisted)
        value.send(.next); value.send(.choose(0)); value.send(.check)
        XCTAssertEqual(memory.attempts.count, 1); XCTAssertEqual(value.state.checked, 1)
    }
    func testFailedRestartRetriesSameCheckpointAndClearsAssistanceOnlyAfterSave() throws {
        let memory = Memory(), engine = ListeningEngine(); let value = model(memory, engine)
        value.send(.load); value.send(.revealTranscript)
        let oldSession = try XCTUnwrap(memory.saved).sessionID
        memory.failSave = true; value.send(.restart)
        let failed = try XCTUnwrap(memory.checkpointWrites.last)
        XCTAssertTrue(value.state.assisted); XCTAssertEqual(memory.saved?.sessionID, oldSession)
        memory.failSave = false; value.send(.retry)
        XCTAssertEqual(memory.checkpointWrites.last, failed)
        XCTAssertNotEqual(memory.saved?.sessionID, oldSession)
        XCTAssertFalse(value.state.assisted); XCTAssertFalse(value.state.transcriptVisible)
        XCTAssertFalse(value.state.heardPlayback)
        play(value, engine); value.send(.choose(0)); value.send(.check)
        XCTAssertEqual(memory.attempts.count, 1)
        XCTAssertFalse(memory.attempts[0].snapshot.metadata!.assisted)
    }
    func testFailedInitialSaveRetainsCheckpointAndTimestampOnRetry() throws {
        let memory = Memory(), engine = ListeningEngine()
        var date = Date(timeIntervalSince1970: 100)
        let value = ListeningComprehensionViewModel(snapshots: questions(), activityKey: "comprehension:test", persistence: memory.persistence, pronunciation: .init(engine: engine), now: { date })
        memory.failSave = true; value.send(.load)
        let failed = try XCTUnwrap(memory.checkpointWrites.last)
        date = Date(timeIntervalSince1970: 200)
        memory.failSave = false; value.send(.retry)
        XCTAssertEqual(memory.saved, failed)
    }
    func testChangedContentOffersRestartAndInitialSaveFailureCanRetry() {
        let memory = Memory(), engine = ListeningEngine(); let value = model(memory, engine)
        memory.failSave = true; value.send(.load); XCTAssertNotNil(value.state.error)
        memory.failSave = false; value.send(.retry); XCTAssertNil(value.state.error)
        var changed = questions(); changed[0].revision = 2; changed[0].fingerprint = changed[0].computedFingerprint
        let new = ListeningComprehensionViewModel(snapshots: changed, activityKey: "comprehension:test", persistence: memory.persistence)
        new.send(.load); XCTAssertTrue(new.state.contentChanged)
        new.send(.restart); XCTAssertFalse(new.state.contentChanged); XCTAssertEqual(memory.saved?.orderedSnapshots, changed)
    }
}

@MainActor private final class ListeningEngine: PronunciationEngine {
    var available = true
    var calls = 0
    var completion: (UUID, (UUID) -> Void)?
    var hasJapaneseVoice: Bool { available }
    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void) throws { calls += 1; self.completion = (id, completion) }
    func stop() {}
    func complete() { if let completion { completion.1(completion.0) } }
}
