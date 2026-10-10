import Observation
import Foundation
import DataKit

struct PracticeExercise: Identifiable, Equatable {
    enum Kind: String { case choice, fillBlank }
    let id: String
    let kind: Kind
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
    private var historicalSnapshot: ExerciseSnapshot?

    init(id: String, kind: Kind, prompt: String, choices: [String], correctIndex: Int, explanation: String) {
        self.id = id; self.kind = kind; self.prompt = prompt; self.choices = choices; self.correctIndex = correctIndex; self.explanation = explanation
    }

    var isValid: Bool {
        !id.isEmpty && !prompt.isEmpty && choices.count >= 2 &&
        Set(choices).count == choices.count && choices.indices.contains(correctIndex) && !explanation.isEmpty
    }
}

extension PracticeExercise {
    var snapshot: ExerciseSnapshot {
        historicalSnapshot ?? ExerciseSnapshot(id: id, revision: 1, questionKind: .choice, prompt: prompt, choices: choices, correctIndex: correctIndex, explanation: explanation)
    }
    init(snapshot: ExerciseSnapshot) {
        id = snapshot.id; kind = .choice; prompt = snapshot.prompt; choices = snapshot.choices
        correctIndex = snapshot.correctIndex ?? -1; explanation = snapshot.explanation; historicalSnapshot = snapshot
    }
}

struct ExercisePersistence {
    var attempts: () throws -> [ExerciseAttempt]
    var checkpoint: (String) throws -> ExerciseCheckpoint?
    var record: (ExerciseAttempt, ExerciseCheckpoint) throws -> Void
    var save: (ExerciseCheckpoint) throws -> Void
    var finish: (String, UUID) throws -> Void
    init(repository: StandardExerciseHistoryRepository) {
        attempts = repository.attempts; checkpoint = repository.checkpoint
        record = repository.record; save = repository.saveCheckpoint; finish = repository.finish
    }
    init(attempts: @escaping () throws -> [ExerciseAttempt], checkpoint: @escaping (String) throws -> ExerciseCheckpoint?, record: @escaping (ExerciseAttempt, ExerciseCheckpoint) throws -> Void, save: @escaping (ExerciseCheckpoint) throws -> Void, finish: @escaping (String, UUID) throws -> Void) {
        self.attempts = attempts; self.checkpoint = checkpoint; self.record = record; self.save = save; self.finish = finish
    }
}

@Observable
final class ExerciseSessionViewModel {
    private let exercises: [PracticeExercise]
    private let persistence: ExercisePersistence?
    private let activityKey: String
    private var sessionID = UUID()
    private var pendingAttempt: ExerciseAttempt?
    private var pendingAction: Action?
    private var loaded = false
    private var sessionAttempts: [ExerciseAttempt] = []
    private(set) var state = State()

    init(exercises: [PracticeExercise], activityKey: String = "", persistence: ExercisePersistence? = nil) {
        self.exercises = exercises; self.activityKey = activityKey; self.persistence = persistence
        resetState()
    }
    var current: PracticeExercise? {
        guard !state.isComplete, !state.hasInvalidContent, exercises.indices.contains(state.position) else { return nil }
        return exercises[state.position]
    }
    private func resetState() {
        state = State(total: exercises.count, hasInvalidContent: exercises.contains { !$0.isValid })
    }
    private func checkpoint(position: Int, revealed: UUID? = nil, session: UUID? = nil) -> ExerciseCheckpoint {
        ExerciseCheckpoint(activityKey: activityKey, sessionID: session ?? sessionID, orderedSnapshots: exercises.map(\.snapshot), position: position, revealedAttemptID: revealed, updatedAt: Date())
    }
    func send(_ action: Action) {
        if case .retry = action {
            guard let pendingAction else { return }
            send(pendingAction); return
        }
        do {
            switch action {
            case .load:
                guard !loaded else { return }
                state.isLoading = true
                if let persistence, let saved = try persistence.checkpoint(activityKey) {
                    guard saved.orderedSnapshots.map(\.fingerprint) == exercises.map({ $0.snapshot.fingerprint }) else {
                        state.contentChanged = true; state.isLoading = false; loaded = true; return
                    }
                    let attempts = try persistence.attempts().filter { $0.sessionID == saved.sessionID }
                    sessionID = saved.sessionID; sessionAttempts = attempts; state.position = saved.position
                    state.correctCount = attempts.filter { $0.outcome == .correct }.count
                    if let id = saved.revealedAttemptID, let attempt = attempts.first(where: { $0.id == id }), case .choice(let index) = attempt.response {
                        state.selectedIndex = index; state.isRevealed = true
                    }
                } else if let persistence, !exercises.isEmpty, !state.hasInvalidContent {
                    try persistence.save(checkpoint(position: 0))
                }
                loaded = true; state.isLoading = false
            case .choose(let index):
                guard (persistence == nil || loaded), !state.isRevealed, !state.contentChanged, let current, current.choices.indices.contains(index) else { return }
                guard pendingAttempt == nil || state.selectedIndex == index else { return }
                state.selectedIndex = index
                let attempt = pendingAttempt ?? ExerciseAttempt(sessionID: sessionID, snapshot: current.snapshot, response: .choice(index), outcome: index == current.correctIndex ? .correct : .incorrect, submittedAt: Date())
                pendingAttempt = attempt
                try persistence?.record(attempt, checkpoint(position: state.position, revealed: attempt.id))
                sessionAttempts.append(attempt)
                state.isRevealed = true
                if attempt.outcome == .correct { state.correctCount += 1 }
                pendingAttempt = nil
            case .next:
                guard state.isRevealed, current != nil else { return }
                if state.position + 1 == exercises.count {
                    try persistence?.finish(activityKey, sessionID); state.isComplete = true
                } else {
                    try persistence?.save(checkpoint(position: state.position + 1))
                    state.position += 1; state.selectedIndex = nil; state.isRevealed = false
                }
            case .restart:
                let newSession = UUID()
                if !exercises.isEmpty, !state.hasInvalidContent { try persistence?.save(checkpoint(position: 0, session: newSession)) }
                sessionID = newSession; pendingAttempt = nil; sessionAttempts = []; resetState(); loaded = true
            case .retry: break
            }
            pendingAction = nil; state.errorMessage = nil
        } catch {
            state.isLoading = false; pendingAction = action
            state.errorMessage = "Your practice couldn't be saved or opened. Retry, or exit and return later."
        }
    }
    struct State {
        var position = 0
        var selectedIndex: Int?
        var correctCount = 0
        var isComplete = false
        var total = 0
        var hasInvalidContent = false
        var isRevealed = false
        var isLoading = false
        var contentChanged = false
        var errorMessage: String?
    }
    enum Action { case load, choose(Int), next, restart, retry }
}
