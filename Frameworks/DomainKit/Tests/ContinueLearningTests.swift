import XCTest
import DataKit
@testable import DomainKit

final class ContinueLearningTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)
    private var steps: [LearningPathStep] { [.init(id: "first", revision: 1, title: "First", activityKey: "grammar", requiredContentIDs: ["a"])] }
    func testNewestValidCheckpointWinsAndTiesAreDeterministic() throws {
        let snapshot = ExerciseSnapshot(id: "a", revision: 1, questionKind: .choice, prompt: "Question", choices: ["A", "B"], correctIndex: 0, explanation: "A")
        let old = ExerciseCheckpoint(activityKey: "old", sessionID: UUID(), orderedSnapshots: [snapshot], position: 0, updatedAt: now)
        let b = ExerciseCheckpoint(activityKey: "b", sessionID: UUID(), orderedSnapshots: [snapshot], position: 0, updatedAt: now.addingTimeInterval(1))
        let a = ExerciseCheckpoint(activityKey: "a", sessionID: UUID(), orderedSnapshots: [snapshot], position: 0, updatedAt: now.addingTimeInterval(1))
        let invalid = ExerciseCheckpoint(activityKey: "changed", sessionID: UUID(), orderedSnapshots: [snapshot], position: 0, updatedAt: now.addingTimeInterval(2))
        let useCase = ContinueLearningUseCase(loadCheckpoints: { [invalid, old, b, a] }, loadProgress: { nil }, steps: steps, validCheckpoint: { $0.activityKey != "changed" })
        XCTAssertEqual(try useCase.execute(), .init(activityKey: "a", sessionID: a.sessionID))
    }
    func testFreshCompletedSkippedAndRevisitedPath() throws {
        let fresh = ContinueLearningUseCase(loadCheckpoints: { [] }, loadProgress: { nil }, steps: steps, validCheckpoint: { _ in true })
        XCTAssertEqual(try fresh.execute(), .init(activityKey: "grammar", stepID: "first"))
        let completed = LearningPathProgress(pathID: "beginner", currentStepID: nil, completedRevisions: [.init(stepID: "first", revision: 1, completedAt: now)], updatedAt: now)
        let finished = ContinueLearningUseCase(loadCheckpoints: { [] }, loadProgress: { completed }, steps: steps, validCheckpoint: { _ in true })
        XCTAssertNil(try finished.execute())
        var revisited = completed; revisited.currentStepID = "first"
        let reopen = ContinueLearningUseCase(loadCheckpoints: { [] }, loadProgress: { revisited }, steps: steps, validCheckpoint: { _ in true })
        XCTAssertEqual(try reopen.execute(), .init(activityKey: "grammar", stepID: "first"))
        let skipped = LearningPathProgress(pathID: "beginner", currentStepID: nil, skippedSteps: [.init(stepID: "first", skippedAt: now)], updatedAt: now)
        let skip = ContinueLearningUseCase(loadCheckpoints: { [] }, loadProgress: { skipped }, steps: steps, validCheckpoint: { _ in true })
        XCTAssertNil(try skip.execute())
    }
    func testRevisionChangeDoesNotInheritCompletion() throws {
        let old = LearningPathProgress(pathID: "beginner", currentStepID: nil, completedRevisions: [.init(stepID: "first", revision: 1, completedAt: now)], updatedAt: now)
        var revised = steps; revised[0].revision = 2
        let useCase = ContinueLearningUseCase(loadCheckpoints: { [] }, loadProgress: { old }, steps: revised, validCheckpoint: { _ in true })
        XCTAssertEqual(try useCase.execute(), .init(activityKey: "grammar", stepID: "first"))
    }
}
