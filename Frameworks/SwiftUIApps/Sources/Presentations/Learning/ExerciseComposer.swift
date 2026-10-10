import SwiftUI
import DataKit

extension AppComposer {
    func makeExerciseSessionView(exercises: [PracticeExercise], activityKey: String, title: String) -> some View {
        ExerciseSessionView(viewModel: .init(exercises: exercises, activityKey: activityKey, persistence: exercisePersistence(activityKey: activityKey)), title: title)
    }
    func exercisePersistence(activityKey: String) -> ExercisePersistence {
        let repository = StandardExerciseHistoryRepository(store: store)
        var persistence = ExercisePersistence(repository: repository)
        if let step = StarterPathCatalog.steps.first(where: { $0.activityKey == activityKey }) {
            persistence.finish = { key, session in
                try repository.finishPath(activityKey: key, sessionID: session, step: step, steps: StarterPathCatalog.steps, pathID: StarterPathCatalog.id, now: Date())
            }
        }
        return persistence
    }
    func makeGrammarExercisesView() -> some View {
        makeExerciseSessionView(exercises: ExerciseCatalog.grammar, activityKey: "grammar", title: "Grammar exercises")
    }
    func makeExerciseHistoryView() -> some View {
        ExerciseHistoryView(viewModel: historyViewModel())
    }
    func makeMistakeReviewView() -> some View {
        MistakeReviewView(viewModel: historyViewModel())
    }
    private func historyViewModel() -> ExerciseHistoryViewModel {
        let repository = StandardExerciseHistoryRepository(store: store)
        return .init(load: repository.attempts, loadCheckpoints: repository.checkpoints, saveCheckpoint: repository.saveCheckpoint)
    }
}
