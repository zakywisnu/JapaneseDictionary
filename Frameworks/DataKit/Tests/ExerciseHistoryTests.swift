import XCTest
import SwiftData
@testable import DataKit

final class ExerciseHistoryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)
    private var snapshot: ExerciseSnapshot { .init(id: "grammar-1", revision: 1, questionKind: .choice, prompt: "Choose", choices: ["A", "B"], correctIndex: 0, explanation: "A is correct") }
    private func attempt(index: Int = 1, session: UUID = UUID()) -> ExerciseAttempt {
        .init(sessionID: session, snapshot: snapshot, response: .choice(index), outcome: index == 0 ? .correct : .incorrect, submittedAt: now)
    }
    private func checkpoint(_ attempt: ExerciseAttempt) -> ExerciseCheckpoint {
        .init(activityKey: "grammar:n5", sessionID: attempt.sessionID, orderedSnapshots: [attempt.snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: now)
    }
    func testRecordRetriesAndConflictingPayload() throws {
        let repository = StandardExerciseHistoryRepository(store: try StudyStore(inMemory: true))
        let value = attempt(), progress = checkpoint(value)
        try repository.record(value, checkpoint: progress)
        try repository.record(value, checkpoint: progress)
        XCTAssertEqual(try repository.attempts(), [value])
        XCTAssertEqual(try repository.checkpoint(activityKey: progress.activityKey), progress)
        var conflict = value; conflict.submittedAt = now.addingTimeInterval(1)
        XCTAssertThrowsError(try repository.record(conflict, checkpoint: progress))
        var wrongSession = progress; wrongSession.sessionID = UUID()
        XCTAssertThrowsError(try repository.record(value, checkpoint: wrongSession))
    }
    func testFailureRollsBackAnswerAndCheckpoint() throws {
        let store = try StudyStore(inMemory: true)
        let repository = StandardExerciseHistoryRepository(store: store, save: { _ in throw Failure.injected })
        let value = attempt()
        XCTAssertThrowsError(try repository.record(value, checkpoint: checkpoint(value)))
        XCTAssertTrue(try repository.attempts().isEmpty)
        XCTAssertTrue(try repository.checkpoints().isEmpty)
    }
    func testDiskReopenPreservesRevealedAnswerAndFinishRetainsHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study.store"), value = attempt(), progress = checkpoint(value)
        try autoreleasepool {
            let repository = StandardExerciseHistoryRepository(store: try StudyStore(url: url))
            try repository.record(value, checkpoint: progress)
        }
        let repository = StandardExerciseHistoryRepository(store: try StudyStore(url: url))
        XCTAssertEqual(try repository.attempts(), [value])
        XCTAssertEqual(try repository.checkpoint(activityKey: progress.activityKey)?.revealedAttemptID, value.id)
        try repository.finish(activityKey: progress.activityKey, sessionID: value.sessionID)
        XCTAssertTrue(try repository.checkpoints().isEmpty)
        XCTAssertEqual(try repository.attempts(), [value])
    }
    func testValidatorRejectsCorruptFingerprintAnswerAndReferences() throws {
        var value = attempt(); value.snapshot.fingerprint = "tampered"
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateAttempt(value))
        value = attempt(); value.response = .choice(9)
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateAttempt(value))
        value = attempt(); value.outcome = .correct
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateAttempt(value))
        let valid = attempt()
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateCheckpoint(checkpoint(valid), attempts: []))
        var progress = checkpoint(valid); progress.orderedSnapshots = [ExerciseSnapshot(id: "other", revision: 1, questionKind: .choice, prompt: "Other", choices: ["A", "B"], correctIndex: 0, explanation: "A")]
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateCheckpoint(progress, attempts: [valid]))
    }
    func testLatestCorrectClearsMistakeAndRevisionsStayDistinct() throws {
        let wrong = attempt()
        var laterWrong = attempt(); laterWrong.submittedAt = now.addingTimeInterval(1)
        XCTAssertEqual(ExerciseHistoryQuery.latestMistakes([wrong, laterWrong]), [laterWrong])
        var correct = attempt(index: 0); correct.submittedAt = now.addingTimeInterval(2)
        XCTAssertTrue(ExerciseHistoryQuery.latestMistakes([wrong, laterWrong, correct]).isEmpty)
        var revision = wrong
        revision.id = UUID(); revision.snapshot = .init(id: "grammar-1", revision: 2, questionKind: .choice, prompt: "Revised", choices: ["A", "B"], correctIndex: 0, explanation: "A")
        XCTAssertEqual(ExerciseHistoryQuery.latestMistakes([wrong, correct, revision]), [revision])
    }
    func testEveryResponseTagRoundtripsAndValidates() throws {
        let kinds: [ExerciseQuestionKind] = [.kanaReading, .romanization, .listeningReading]
        for kind in kinds {
            let snapshot = ExerciseSnapshot(id: kind.rawValue, revision: 1, questionKind: kind, prompt: "森", acceptedAnswers: ["もり"], explanation: "Reading")
            let value = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .text("もり"), outcome: .correct, submittedAt: now)
            try ExerciseHistoryValidator.validateAttempt(value)
            XCTAssertEqual(try JSONDecoder().decode(ExerciseAttempt.self, from: JSONEncoder().encode(value)), value)
        }
        let snapshot = ExerciseSnapshot(id: "meaning", revision: 1, questionKind: .meaningSelfRated, prompt: "森", explanation: "Forest")
        let value = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .selfRating(true), outcome: .selfRated, submittedAt: now)
        try ExerciseHistoryValidator.validateAttempt(value)
        XCTAssertEqual(try JSONDecoder().decode(ExerciseAttempt.self, from: JSONEncoder().encode(value)), value)
    }
    func testRatingEventsAreAtomicImmutableAndSurviveDeletion() throws {
        let store = try StudyStore(inMemory: true)
        let materials = StandardStudyMaterialRepository(store: store)
        let material = try materials.save(StudyMaterial(id: UUID().uuidString, kind: .customCard, prompt: "森", answer: "Forest", createdAt: now, updatedAt: now))
        let id = SavedStudyID(kind: material.kind, id: material.id), session = UUID(), action = UUID()
        let repository = StandardStudyRatingRepository(store: store)
        try repository.record(id: id, sessionID: session, actionID: action, again: true, now: now)
        try repository.record(id: id, sessionID: session, actionID: action, again: true, now: now)
        XCTAssertEqual(try repository.events().count, 1)
        XCTAssertThrowsError(try repository.record(id: id, sessionID: session, actionID: action, again: false, now: now))
        let failure = StandardStudyRatingRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failure.record(id: id, sessionID: UUID(), actionID: UUID(), again: false, now: now))
        XCTAssertEqual(try repository.events().count, 1)
        XCTAssertEqual(try repository.records().first?.missCount, 1)
        try materials.delete(id)
        XCTAssertEqual(try repository.events().count, 1)
        try repository.record(id: id, sessionID: session, actionID: action, again: true, now: now)
        XCTAssertEqual(try repository.events().count, 1)
    }
    func testStoredPayloadIdentityMismatchIsRejected() throws {
        let attempt = attempt()
        let attemptModel = try ExerciseAttemptModel(value: attempt)
        attemptModel.id = UUID()
        XCTAssertThrowsError(try attemptModel.value())
        let checkpointModel = try ExerciseCheckpointModel(value: checkpoint(attempt))
        checkpointModel.activityKey = "changed"
        XCTAssertThrowsError(try checkpointModel.value())
        let eventModel = try ReviewRatingEventModel(value: .init(actionID: UUID(), sessionID: UUID(), id: .init(kind: .word, id: "word"), again: true, submittedAt: now))
        eventModel.actionID = UUID()
        XCTAssertThrowsError(try eventModel.value())
    }
    func testHistoryPruningPreservesUnfinishedSessionAndRollsBackOnFailure() throws {
        let store = try StudyStore(inMemory: true), protectedSession = UUID()
        let protected = attempt(session: protectedSession)
        let context = store.makeContext()
        context.insert(try ExerciseAttemptModel(value: protected))
        context.insert(try ExerciseCheckpointModel(value: checkpoint(protected)))
        var oldestRemovable: UUID?
        for index in 0..<9_999 {
            var value = attempt()
            value.submittedAt = now.addingTimeInterval(Double(index + 1))
            if index == 0 { oldestRemovable = value.id }
            context.insert(try ExerciseAttemptModel(value: value))
        }
        try context.save()
        var next = attempt(); next.submittedAt = now.addingTimeInterval(20_000)
        var nextCheckpoint = checkpoint(next); nextCheckpoint.activityKey = "new-session"; nextCheckpoint.updatedAt = next.submittedAt
        let failing = StandardExerciseHistoryRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failing.record(next, checkpoint: nextCheckpoint))
        XCTAssertEqual(try failing.attempts().count, 10_000)
        XCTAssertTrue(try failing.attempts().contains { $0.id == oldestRemovable })
        let repository = StandardExerciseHistoryRepository(store: store)
        try repository.record(next, checkpoint: nextCheckpoint)
        let retained = try repository.attempts()
        XCTAssertEqual(retained.count, 10_000)
        XCTAssertTrue(retained.contains { $0.id == protected.id })
        XCTAssertTrue(retained.contains { $0.id == next.id })
        XCTAssertFalse(retained.contains { $0.id == oldestRemovable })
    }
    func testReviewEventRetentionIsBoundedAndTransactional() throws {
        let store = try StudyStore(inMemory: true)
        let material = try StandardStudyMaterialRepository(store: store).save(StudyMaterial(id: UUID().uuidString, kind: .customCard, prompt: "森", answer: "Forest", createdAt: now, updatedAt: now))
        let id = SavedStudyID(kind: material.kind, id: material.id)
        let context = store.makeContext()
        var oldest: UUID?
        let oldestSession = UUID()
        for index in 0..<10_000 {
            let actionID = UUID()
            if index == 0 { oldest = actionID }
            context.insert(try ReviewRatingEventModel(value: .init(actionID: actionID, sessionID: index < 2 ? oldestSession : UUID(), id: id, again: index == 0, submittedAt: now.addingTimeInterval(Double(index)))))
        }
        try context.save()
        let action = UUID(), session = UUID(), submittedAt = now.addingTimeInterval(20_000)
        let failure = StandardStudyRatingRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failure.record(id: id, sessionID: session, actionID: action, again: false, now: submittedAt))
        XCTAssertEqual(try failure.events().count, 10_000)
        XCTAssertTrue(try failure.events().contains { $0.actionID == oldest })
        let repository = StandardStudyRatingRepository(store: store)
        try repository.record(id: id, sessionID: session, actionID: action, again: false, now: submittedAt)
        XCTAssertEqual(try repository.events().count, 9_999)
        XCTAssertFalse(try repository.events().contains { $0.actionID == oldest })
        XCTAssertFalse(try repository.events().contains { $0.sessionID == oldestSession })
        try repository.record(id: id, sessionID: session, actionID: action, again: false, now: submittedAt)
        XCTAssertEqual(try repository.events().count, 9_999)
    }
    private enum Failure: Error { case injected }
}
