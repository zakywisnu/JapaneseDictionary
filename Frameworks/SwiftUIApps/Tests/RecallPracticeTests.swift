import XCTest
import DataKit
@testable import SwiftUIApps

@MainActor
final class RecallPracticeTests: XCTestCase {
    enum Failure: Error { case save }
    private var question: RecallQuestion {
        .init(snapshot: .init(id: "typed:test", revision: 1, questionKind: .kanaReading, prompt: "切手", acceptedAnswers: ["きって"], explanation: "Supplied reading"))
    }
    private func memory(record: @escaping (ExerciseAttempt, ExerciseCheckpoint) throws -> Void = { _, _ in }, saved: ExerciseCheckpoint? = nil, attempts: [ExerciseAttempt] = []) -> ExercisePersistence {
        .init(attempts: { attempts }, checkpoint: { _ in saved }, record: record, save: { _ in }, finish: { _, _ in })
    }
    func testExplicitCheckLocksDraftAndRetryPreservesRawPayload() {
        var writes: [ExerciseAttempt] = []; var fails = true
        let model = RecallSessionViewModel(questions: [question], activityKey: "typed:test", persistence: memory(record: { attempt, _ in writes.append(attempt); if fails { throw Failure.save } }))
        model.send(.load); model.send(.draft(" キッテ "))
        XCTAssertTrue(writes.isEmpty)
        model.send(.submit)
        XCTAssertEqual(model.state.draft, " キッテ ")
        XCTAssertFalse(model.state.isRevealed)
        model.send(.draft("different"))
        XCTAssertEqual(model.state.draft, " キッテ ")
        fails = false; model.send(.retry)
        XCTAssertEqual(writes.count, 2); XCTAssertEqual(writes[0], writes[1])
        XCTAssertEqual(writes[0].response, .text(" キッテ "))
        XCTAssertEqual(writes[0].outcome, .correct)
        model.send(.submit); XCTAssertEqual(writes.count, 2)
    }
    func testNextClearsDraftAndResumeRestoresFeedback() {
        let attempt = ExerciseAttempt(sessionID: UUID(), snapshot: question.snapshot, response: .text("きて"), outcome: .incorrect, submittedAt: Date())
        let saved = ExerciseCheckpoint(activityKey: "typed:test", sessionID: attempt.sessionID, orderedSnapshots: [question.snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: Date())
        let restored = RecallSessionViewModel(questions: [question], activityKey: "typed:test", persistence: memory(saved: saved, attempts: [attempt]))
        restored.send(.load)
        XCTAssertTrue(restored.state.isRevealed); XCTAssertEqual(restored.state.draft, "きて")
        let second = RecallQuestion(snapshot: .init(id: "next", revision: 1, questionKind: .romanization, prompt: "し", acceptedAnswers: ["shi", "si"], explanation: "Supplied aliases"))
        let model = RecallSessionViewModel(questions: [question, second], activityKey: "typed:new", persistence: memory())
        model.send(.load); model.send(.draft("きって")); model.send(.submit); model.send(.next)
        XCTAssertEqual(model.state.position, 1); XCTAssertEqual(model.state.draft, ""); XCTAssertFalse(model.state.isRevealed)
    }
    func testMeaningRecallIsExplicitSelfRating() {
        let meaning = RecallQuestion(snapshot: .init(id: "meaning", revision: 1, questionKind: .meaningSelfRated, prompt: "青", explanation: "blue"))
        var attempts: [ExerciseAttempt] = []
        let model = RecallSessionViewModel(questions: [meaning], activityKey: "typed:meaning", persistence: memory(record: { value, _ in attempts.append(value) }))
        model.send(.load); model.send(.draft("a synonym")); model.send(.submit)
        XCTAssertTrue(attempts.isEmpty)
        model.send(.reveal); XCTAssertTrue(attempts.isEmpty)
        model.send(.rate(false))
        XCTAssertEqual(attempts.first?.outcome, .selfRated)
        XCTAssertEqual(attempts.first?.response, .selfRating(false))
        XCTAssertEqual(model.state.checkedCount, 0); XCTAssertEqual(model.state.selfRatedCount, 1)
    }
    func testListeningNoVoiceOrPlaybackFailureNeverRecordsWrongAnswer() {
        let engine = RecallEngine(); engine.available = false
        let service = PronunciationService(engine: engine)
        let listening = RecallQuestion(snapshot: .init(id: "listening:test", revision: 1, questionKind: .listeningReading, prompt: "切手", acceptedAnswers: ["きって"], explanation: "Supplied reading"), suppliedReading: "きって")
        var attempts: [ExerciseAttempt] = []
        let model = RecallSessionViewModel(questions: [listening], activityKey: "listening:test", isListening: true, persistence: memory(record: { value, _ in attempts.append(value) }), pronunciation: service)
        model.send(.load)
        XCTAssertFalse(model.promptVisible); XCTAssertEqual(engine.calls, 0)
        model.send(.play); model.send(.draft("wrong")); model.send(.submit)
        XCTAssertNotNil(model.playbackFailure); XCTAssertTrue(attempts.isEmpty)
        engine.available = true; engine.fail = true; model.send(.play); model.send(.submit)
        XCTAssertTrue(attempts.isEmpty)
    }
    func testListeningIgnoresStaleCompletionAndRequiresSuccessfulPlayback() {
        let engine = RecallEngine()
        let service = PronunciationService(engine: engine)
        let listening = RecallQuestion(snapshot: .init(id: "listen", revision: 1, questionKind: .listeningReading, prompt: "切手", acceptedAnswers: ["きって"], explanation: "Reading"), suppliedReading: "きって")
        var attempts: [ExerciseAttempt] = []
        let model = RecallSessionViewModel(questions: [listening], activityKey: "listening:test", isListening: true, persistence: memory(record: { value, _ in attempts.append(value) }), pronunciation: service)
        model.send(.load); model.send(.play)
        let old = engine.completions[0]; model.send(.play)
        old.1(old.0); model.send(.playbackChanged)
        XCTAssertFalse(model.state.heardPlayback)
        let latest = engine.completions[1]; latest.1(latest.0); model.send(.playbackChanged)
        XCTAssertTrue(model.state.heardPlayback)
        model.send(.draft("キッテ")); model.send(.submit)
        XCTAssertTrue(model.promptVisible); XCTAssertEqual(attempts.first?.outcome, .correct)
        model.send(.cancel); XCTAssertEqual(service.state, .idle)
    }
    func testListeningTimeoutDoesNotPermitScoring() {
        let engine = RecallEngine(); var timeout: (@MainActor () -> Void)?
        let service = PronunciationService(engine: engine, scheduleTimeout: { _, action in timeout = action; return {} })
        let question = RecallQuestion(snapshot: .init(id: "listen", revision: 1, questionKind: .listeningReading, prompt: "あ", acceptedAnswers: ["あ"], explanation: "Reading"), suppliedReading: "あ")
        var count = 0
        let model = RecallSessionViewModel(questions: [question], activityKey: "listening:test", isListening: true, persistence: memory(record: { _, _ in count += 1 }), pronunciation: service)
        model.send(.load); model.send(.play); timeout?(); model.send(.playbackChanged); model.send(.draft("あ")); model.send(.submit)
        XCTAssertNotNil(model.playbackFailure); XCTAssertEqual(count, 0)
    }
}

@MainActor
private final class RecallEngine: PronunciationEngine {
    var available = true
    var fail = false
    var calls = 0
    var completions: [(UUID, (UUID) -> Void)] = []
    var hasJapaneseVoice: Bool { available }
    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void) throws {
        calls += 1
        if fail { throw RecallPracticeTests.Failure.save }
        completions.append((id, completion))
    }
    func stop() {}
}
