import XCTest
import SwiftData
@testable import DataKit

final class AppliedPracticeBackupTests: XCTestCase {
    private func snapshot() -> ExerciseSnapshot {
        .init(id: "past", revision: 1, questionKind: .conjugation, prompt: "書く past", acceptedAnswers: ["書いた"], explanation: "く becomes いた", metadata: .init(activityKind: "conjugation", topicID: "godan-past", source: "Original"))
    }
    func testFormatSevenReopensAndRejectsDowngradeWithoutReplacingHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study.store")
        let store = try StudyStore(url: url)
        let history = StandardExerciseHistoryRepository(store: store)
        let attempt = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot(), response: .text("書いた"), outcome: .correct, submittedAt: Date())
        let checkpoint = ExerciseCheckpoint(activityKey: "conjugation:test", sessionID: attempt.sessionID, orderedSnapshots: [attempt.snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: attempt.submittedAt)
        try history.record(attempt, checkpoint: checkpoint)
        let repository = BackupRepository(store: store, catalog: .init(words: [], kanjis: []), recoveryURL: directory.appendingPathComponent("recovery.json"))
        var backup = try repository.validate(repository.export(preferences: .init()))
        XCTAssertEqual(backup.formatVersion, 7)
        try repository.restore(backup, currentPreferences: .init())
        XCTAssertEqual(try StandardExerciseHistoryRepository(store: StudyStore(url: url)).attempts(), [attempt])
        backup.formatVersion = 6
        XCTAssertThrowsError(try repository.restore(backup, currentPreferences: .init()))
        XCTAssertEqual(try history.attempts(), [attempt])
    }
    func testSaveFailureRestoresNewHistoryAndCheckpointAfterReplacement() throws {
        enum Failure: Error { case save }
        let store = try StudyStore(inMemory: true)
        let history = StandardExerciseHistoryRepository(store: store)
        let attempt = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot(), response: .text("違う"), outcome: .incorrect, submittedAt: Date())
        let checkpoint = ExerciseCheckpoint(activityKey: "conjugation:test", sessionID: attempt.sessionID, orderedSnapshots: [attempt.snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: attempt.submittedAt)
        try history.record(attempt, checkpoint: checkpoint)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = BackupRepository(store: store, catalog: .init(words: [], kanjis: []), recoveryURL: url, save: { _ in throw Failure.save })
        var replacement = try repository.validate(repository.export(preferences: .init()))
        replacement.attempts = []; replacement.checkpoints = []
        XCTAssertThrowsError(try repository.restore(replacement, currentPreferences: .init()))
        XCTAssertEqual(try history.attempts(), [attempt])
        XCTAssertEqual(try history.checkpoints(), [checkpoint])
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
    func testContextIDValidationAndLegacyDecode() throws {
        let event = ReviewRatingEvent(actionID: UUID(), sessionID: UUID(), id: .init(kind: .word, id: "saved"), again: false, submittedAt: Date(), contextID: "context:blue")
        try ExerciseHistoryValidator.validateReviewRatingEvent(event)
        XCTAssertEqual(try JSONDecoder().decode(ReviewRatingEvent.self, from: JSONEncoder().encode(event)), event)
        for bad in ["", "  ", String(repeating: "a", count: 257)] {
            var copy = event; copy.contextID = bad
            XCTAssertThrowsError(try ExerciseHistoryValidator.validateReviewRatingEvent(copy))
        }
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        object.removeValue(forKey: "contextID")
        XCTAssertNil(try JSONDecoder().decode(ReviewRatingEvent.self, from: JSONSerialization.data(withJSONObject: object)).contextID)
    }
    func testNewRecordsParticipateInRestoreRollback() throws {
        let store = try StudyStore(inMemory: true)
        let history = StandardExerciseHistoryRepository(store: store)
        let attempt = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot(), response: .text("違う"), outcome: .incorrect, submittedAt: Date())
        let checkpoint = ExerciseCheckpoint(activityKey: "conjugation:test", sessionID: attempt.sessionID, orderedSnapshots: [attempt.snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: attempt.submittedAt)
        try history.record(attempt, checkpoint: checkpoint)
        let repository = BackupRepository(store: store, catalog: .init(words: [], kanjis: []), recoveryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        var backup = try repository.validate(repository.export(preferences: .init()))
        backup.attempts[0].snapshot.metadata?.schemaVersion = 999
        XCTAssertThrowsError(try repository.restore(backup, currentPreferences: .init()))
        XCTAssertEqual(try history.attempts(), [attempt])
        XCTAssertEqual(try history.checkpoints(), [checkpoint])
    }
}
