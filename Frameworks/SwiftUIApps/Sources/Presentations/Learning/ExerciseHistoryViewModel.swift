import Observation
import Foundation
import DataKit

@Observable
final class ExerciseHistoryViewModel {
    private let loadCheckpoints: () throws -> [ExerciseCheckpoint]
    private let saveCheckpoint: ((ExerciseCheckpoint) throws -> Void)?
    private var pendingMistakeCheckpoint: ExerciseCheckpoint?
    private let load: () throws -> [ExerciseAttempt]
    private(set) var state = State()
    init(load: @escaping () throws -> [ExerciseAttempt], loadCheckpoints: @escaping () throws -> [ExerciseCheckpoint] = { [] }, saveCheckpoint: ((ExerciseCheckpoint) throws -> Void)? = nil) {
        self.load = load; self.loadCheckpoints = loadCheckpoints; self.saveCheckpoint = saveCheckpoint
    }
    func send(_ action: Action) {
        if case .startMistakes = action {
            guard let saveCheckpoint, !state.mistakes.isEmpty else { return }
            let checkpoint = pendingMistakeCheckpoint ?? ExerciseCheckpoint(activityKey: "mistakes:" + UUID().uuidString, sessionID: UUID(), orderedSnapshots: Array(state.mistakes.prefix(1_000)).map(\.snapshot), position: 0, updatedAt: Date())
            pendingMistakeCheckpoint = checkpoint
            do { try saveCheckpoint(checkpoint); state.startedKey = checkpoint.activityKey; state.startError = nil; pendingMistakeCheckpoint = nil }
            catch { state.startError = "Mistake practice couldn't be saved. Try Practice these mistakes again." }
            return
        }
        state.startedKey = nil
        state.isLoading = true; state.errorMessage = nil
        do {
            state.attempts = try load().sorted {
                $0.submittedAt == $1.submittedAt ? $0.id.uuidString > $1.id.uuidString : $0.submittedAt > $1.submittedAt
            }
            state.mistakes = ExerciseHistoryQuery.latestMistakes(state.attempts)
            state.checkpoints = try loadCheckpoints().sorted { $0.updatedAt > $1.updatedAt }
        } catch { state.errorMessage = "Your submitted answers couldn't be opened. Try again." }
        state.isLoading = false
    }
    struct State {
        var isLoading = true
        var attempts: [ExerciseAttempt] = []
        var mistakes: [ExerciseAttempt] = []
        var errorMessage: String?
        var checkpoints: [ExerciseCheckpoint] = []
        var startedKey: String?
        var startError: String?
    }
    enum Action { case load, startMistakes }
}
