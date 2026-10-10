import XCTest
@testable import DataKit

final class ExerciseBackupTests: XCTestCase {
    func testHistoryRoundTripAndLegacyReplacement() throws {
        let store = try StudyStore(inMemory: true)
        let repository = StandardExerciseHistoryRepository(store: store)
        let snapshot = ExerciseSnapshot(id: "original", revision: 1, questionKind: .choice, prompt: "Choose", choices: ["A", "B"], correctIndex: 0, explanation: "A is correct")
        let attempt = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .choice(1), outcome: .incorrect, submittedAt: Date())
        let checkpoint = ExerciseCheckpoint(activityKey: "grammar", sessionID: attempt.sessionID, orderedSnapshots: [snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: attempt.submittedAt)
        try repository.record(attempt, checkpoint: checkpoint)
        let backup = BackupRepository(store: store, catalog: .init(words: [], kanjis: []), recoveryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        var value = try backup.validate(backup.export(preferences: .init()))
        XCTAssertEqual(value.attempts, [attempt])
        XCTAssertEqual(value.checkpoints, [checkpoint])
        try backup.restore(value, currentPreferences: .init())
        XCTAssertEqual(try repository.attempts(), [attempt])
        value.formatVersion = 4
        XCTAssertThrowsError(try backup.validate(value))
        value.attempts = []; value.checkpoints = []; value.reviewRatingEvents = []
        try backup.restore(value, currentPreferences: .init())
        XCTAssertTrue(try repository.attempts().isEmpty)
        XCTAssertTrue(try repository.checkpoints().isEmpty)
    }

    func testPathAndPassageSourceRoundTripAndLegacyDefaults() throws {
        let store = try StudyStore(inMemory: true)
        let date = Date()
        let path = LearningPathProgress(pathID: "starter", currentStepID: "kana", completedRevisions: [.init(stepID: "old", revision: 1, completedAt: date)], updatedAt: date)
        store.context.insert(try LearningPathProgressModel(value: path))
        store.context.insert(StudyListModel(id: "passage-list", name: "Renamed", createdAt: date, sourceKey: "passage:morning"))
        try store.context.save()
        let repo = BackupRepository(store: store, catalog: .init(words: [], kanjis: []), recoveryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        var backup = try repo.validate(repo.export(preferences: .init()))
        XCTAssertEqual(backup.formatVersion, 6)
        XCTAssertEqual(backup.pathProgress, [path])
        XCTAssertEqual(backup.lists.first?.sourceKey, "passage:morning")
        try repo.restore(backup, currentPreferences: .init())
        XCTAssertEqual(try StandardLearningPathRepository(store: store).progress(pathID: "starter"), path)
        backup.formatVersion = 5
        XCTAssertThrowsError(try repo.validate(backup))
        backup.pathProgress = []
        try repo.restore(backup, currentPreferences: .init())
        XCTAssertTrue(try StandardLearningPathRepository(store: store).allProgress().isEmpty)
        backup.lists.append(.init(id: "duplicate", name: "Other", createdAt: date, sourceKey: "passage:morning"))
        XCTAssertThrowsError(try repo.validate(backup))
        backup.lists = [.init(id: "bad", name: "Bad", createdAt: date, sourceKey: "passage:   ")]
        XCTAssertThrowsError(try repo.validate(backup))
    }

    func testFormatFiveRequiresHistoryFields() throws {
        let value = StudyBackup(formatVersion: 5, createdAt: Date(), catalogFingerprint: "test", words: [], kanjis: [], progress: nil, reviews: [], preferences: .init())
        let encoded = try JSONEncoder().encode(value)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "attempts")
        XCTAssertThrowsError(try JSONDecoder().decode(StudyBackup.self, from: JSONSerialization.data(withJSONObject: object)))
    }
}
