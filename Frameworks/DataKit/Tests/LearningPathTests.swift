import XCTest
import SwiftData
@testable import DataKit

final class LearningPathTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)
    private var steps: [LearningPathStep] {
        [.init(id: "first", revision: 1, title: "First", activityKey: "grammar:1", requiredContentIDs: ["a", "b"]), .init(id: "second", revision: 1, title: "Second", activityKey: "grammar:2", requiredContentIDs: ["c"])]
    }
    func testCompletionNeedsEveryCurrentRevisionAttemptWithoutCorrectnessGate() throws {
        let store = try StudyStore(inMemory: true), repository = StandardLearningPathRepository(store: store)
        XCTAssertThrowsError(try repository.complete(step: steps[0], steps: steps, pathID: "beginner", now: now))
        try persist(id: "a", revision: 1, store: store)
        try persist(id: "b", revision: 2, store: store)
        XCTAssertThrowsError(try repository.complete(step: steps[0], steps: steps, pathID: "beginner", now: now))
        try persist(id: "b", revision: 1, store: store)
        let progress = try repository.complete(step: steps[0], steps: steps, pathID: "beginner", now: now)
        XCTAssertTrue(progress.isComplete(steps[0])); XCTAssertEqual(progress.currentStepID, "second")
        XCTAssertEqual(try repository.complete(step: steps[0], steps: steps, pathID: "beginner", now: now).completedRevisions.count, 1)
        var revised = steps[0]; revised.revision = 2
        XCTAssertFalse(progress.isComplete(revised))
        XCTAssertEqual(progress.completedRevisions.first?.revision, 1)
    }
    func testSkipAndRevisitKeepCompletionSeparate() throws {
        let repository = StandardLearningPathRepository(store: try StudyStore(inMemory: true))
        let skipped = try repository.skip(stepID: "first", steps: steps, pathID: "beginner", now: now)
        XCTAssertEqual(skipped.skippedStepIDs, ["first"]); XCTAssertTrue(skipped.completedRevisions.isEmpty)
        XCTAssertEqual(skipped.currentStepID, "second")
        let revisited = try repository.revisit(stepID: "first", steps: steps, pathID: "beginner", now: now.addingTimeInterval(1))
        XCTAssertTrue(revisited.skippedStepIDs.isEmpty); XCTAssertEqual(revisited.currentStepID, "first")
    }
    func testSaveFailureRollsBackPathState() throws {
        let store = try StudyStore(inMemory: true)
        let repository = StandardLearningPathRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try repository.skip(stepID: "first", steps: steps, pathID: "beginner", now: now))
        XCTAssertTrue(try repository.allProgress().isEmpty)
    }
    func testDiskReopenRetainsProgressAndDates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study.store")
        let expected: LearningPathProgress
        do { expected = try StandardLearningPathRepository(store: StudyStore(url: url)).skip(stepID: "first", steps: steps, pathID: "beginner", now: now) }
        XCTAssertEqual(try StandardLearningPathRepository(store: StudyStore(url: url)).progress(pathID: "beginner"), expected)
    }
    func testReferenceAndDuplicateValidation() throws {
        let valid = LearningPathProgress(pathID: "beginner", currentStepID: "first", updatedAt: now)
        try LearningPathValidator.validate(valid, steps: steps)
        var invalid = valid; invalid.currentStepID = "missing"
        XCTAssertThrowsError(try LearningPathValidator.validate(invalid, steps: steps))
        invalid = valid; invalid.skippedSteps = [.init(stepID: "first", skippedAt: now), .init(stepID: "first", skippedAt: now)]
        XCTAssertThrowsError(try LearningPathValidator.validate(invalid))
        XCTAssertThrowsError(try LearningPathValidator.validateSteps(steps, availableContentIDs: ["a", "b"]))
        try LearningPathValidator.validateSteps(steps, availableContentIDs: ["a", "b", "c"])
        XCTAssertFalse(LearningStepCompletionPolicy().isComplete(step: steps[0], attemptedIDs: ["a"]))
        XCTAssertTrue(LearningStepCompletionPolicy().isComplete(step: steps[0], attemptedIDs: ["a", "b"]))
    }
    func testFinishAdvancesPathAtomicallyAndFailurePreservesCheckpoint() throws {
        enum Failure: Error { case injected }
        let store = try StudyStore(inMemory: true)
        try persist(id: "a", revision: 1, store: store)
        try persist(id: "b", revision: 1, store: store)
        let history = StandardExerciseHistoryRepository(store: store)
        let snapshots = try history.attempts().map(\.snapshot)
        let checkpoint = ExerciseCheckpoint(activityKey: steps[0].activityKey, sessionID: UUID(), orderedSnapshots: snapshots, position: 1, updatedAt: now)
        try history.saveCheckpoint(checkpoint)
        let failing = StandardExerciseHistoryRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failing.finishPath(activityKey: checkpoint.activityKey, sessionID: checkpoint.sessionID, step: steps[0], steps: steps, pathID: "beginner", now: now))
        XCTAssertEqual(try history.checkpoint(activityKey: checkpoint.activityKey), checkpoint)
        XCTAssertNil(try StandardLearningPathRepository(store: store).progress(pathID: "beginner"))
        try history.finishPath(activityKey: checkpoint.activityKey, sessionID: checkpoint.sessionID, step: steps[0], steps: steps, pathID: "beginner", now: now)
        XCTAssertNil(try history.checkpoint(activityKey: checkpoint.activityKey))
        let progress = try XCTUnwrap(StandardLearningPathRepository(store: store).progress(pathID: "beginner"))
        XCTAssertTrue(progress.isComplete(steps[0]))
        XCTAssertEqual(progress.currentStepID, "second")
        XCTAssertEqual(try history.attempts().count, 2)
    }
    func testFinishingUngradedStepDoesNotClaimCompletion() throws {
        let store = try StudyStore(inMemory: true), history = StandardExerciseHistoryRepository(store: store)
        try persist(id: "a", revision: 1, store: store)
        let snapshot = try XCTUnwrap(history.attempts().first?.snapshot)
        let checkpoint = ExerciseCheckpoint(activityKey: steps[0].activityKey, sessionID: UUID(), orderedSnapshots: [snapshot], position: 0, updatedAt: now)
        try history.saveCheckpoint(checkpoint)
        XCTAssertThrowsError(try history.finishPath(activityKey: checkpoint.activityKey, sessionID: UUID(), step: steps[0], steps: steps, pathID: "beginner", now: now))
        XCTAssertNotNil(try history.checkpoint(activityKey: checkpoint.activityKey))
        try history.finishPath(activityKey: checkpoint.activityKey, sessionID: checkpoint.sessionID, step: steps[0], steps: steps, pathID: "beginner", now: now)
        XCTAssertNil(try StandardLearningPathRepository(store: store).progress(pathID: "beginner"))
        XCTAssertNil(try history.checkpoint(activityKey: checkpoint.activityKey))
    }
    private func persist(id: String, revision: Int, store: StudyStore) throws {
        let snapshot = ExerciseSnapshot(id: id, revision: revision, questionKind: .choice, prompt: "Question", choices: ["A", "B"], correctIndex: 0, explanation: "A")
        let attempt = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .choice(1), outcome: .incorrect, submittedAt: now)
        let checkpoint = ExerciseCheckpoint(activityKey: "practice:\(id)", sessionID: attempt.sessionID, orderedSnapshots: [snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: now)
        try StandardExerciseHistoryRepository(store: store).record(attempt, checkpoint: checkpoint)
    }
    private enum Failure: Error { case injected }
}
