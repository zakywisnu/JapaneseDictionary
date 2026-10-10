import XCTest
import DataKit
@testable import SwiftUIApps

final class StarterPathCatalogTests: XCTestCase {
    func testPathShowsCurrentAndAttemptedAndUpdatesAfterSkip() throws {
        let store = try StudyStore(inMemory: true)
        let history = StandardExerciseHistoryRepository(store: store)
        let entry = try XCTUnwrap(KanaCatalog.entries.first { $0.script == .hiragana && $0.group == .voiced })
        let snapshot = ExerciseSnapshot(id: entry.id, revision: 1, questionKind: .romanization, prompt: entry.kana, acceptedAnswers: [entry.romanization], explanation: entry.note)
        let attempt = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .text(entry.romanization), outcome: .correct, submittedAt: Date())
        try history.record(attempt, checkpoint: .init(activityKey: "test", sessionID: attempt.sessionID, orderedSnapshots: [snapshot], position: 0, revealedAttemptID: attempt.id, updatedAt: attempt.submittedAt))
        let model = LearningPathViewModel(repository: StandardLearningPathRepository(store: store), loadAttempts: history.attempts)
        model.send(.load)
        XCTAssertEqual(model.state.statuses.first?.status, .current)
        XCTAssertEqual(model.state.statuses.first { $0.stepID == "hiragana-voiced" }?.status, .attempted)
        model.send(.skip("hiragana-basic"))
        XCTAssertEqual(model.state.statuses.first?.status, .skipped)
        XCTAssertEqual(model.state.statuses.first { $0.stepID == "hiragana-voiced" }?.status, .current)
    }
    func testEveryStepReferencesCurrentPracticeAndRevision() throws {
        let available = Set(KanaCatalog.entries.map(\.id) + ExerciseCatalog.grammar.map(\.id) + ReadingCatalog.passages.flatMap { $0.questions.map(\.id) })
        XCTAssertEqual(StarterPathCatalog.steps.count, 8)
        try LearningPathValidator.validateSteps(StarterPathCatalog.steps, availableContentIDs: available)
        for step in StarterPathCatalog.steps {
            if let group = StarterPathCatalog.kanaGroups.first(where: { $0.0 == step.id }) {
                let questions = KanaCatalog.entries.filter { $0.script == group.1 && $0.group == group.2 }.compactMap { RecallSelectionViewModel.kanaQuestion($0, mode: .romanization, listening: false) }
                XCTAssertEqual(Set(questions.map(\.id)), Set(step.requiredContentIDs))
            } else { XCTAssertEqual(Set(StarterPathCatalog.exercises(for: step.id).map(\.id)), Set(step.requiredContentIDs)) }
        }
    }
}
