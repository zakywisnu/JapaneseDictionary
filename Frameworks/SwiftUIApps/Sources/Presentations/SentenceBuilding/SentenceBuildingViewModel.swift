import Foundation
import Observation
import DataKit
import DomainKit

@Observable
final class SentenceBuildingViewModel {
    private let snapshots: [ExerciseSnapshot]
    private let activityKey: String
    private let persistence: ExercisePersistence
    private var sessionID = UUID()
    private var loaded = false
    private var pendingAttempt: ExerciseAttempt?
    private var pendingCheckpoint: ExerciseCheckpoint?
    private var pendingAction: Action?
    private(set) var state: State

    init(snapshots: [ExerciseSnapshot], activityKey: String, persistence: ExercisePersistence) {
        self.snapshots = snapshots; self.activityKey = activityKey; self.persistence = persistence
        state = State(total: snapshots.count, hasInvalidContent: snapshots.contains { snapshot in
            snapshot.questionKind != .sentenceOrder || (try? ExerciseHistoryValidator.validateSnapshot(snapshot)) == nil
        })
    }
    var current: ExerciseSnapshot? {
        guard !state.isComplete, !state.hasInvalidContent, snapshots.indices.contains(state.position) else { return nil }
        return snapshots[state.position]
    }
    var canEdit: Bool { loaded && !state.isRevealed && !state.contentChanged && state.errorMessage == nil && current != nil }
    var canCheck: Bool {
        guard canEdit, let metadata = current?.metadata else { return false }
        return state.selectedIDs.count == metadata.tokens.count && Set(state.selectedIDs) == Set(metadata.tokens.map(\.id))
    }
    private func checkpoint(position: Int, revealed: UUID? = nil, session: UUID? = nil) -> ExerciseCheckpoint {
        ExerciseCheckpoint(activityKey: activityKey, sessionID: session ?? sessionID, orderedSnapshots: snapshots, position: position, revealedAttemptID: revealed, updatedAt: Date())
    }
    func send(_ action: Action) {
        if case .retry = action { if let pendingAction { send(pendingAction) }; return }
        guard pendingAction == nil || pendingAction == action else { return }
        do {
            switch action {
            case .load:
                guard !loaded else { return }
                state.isLoading = true
                if let saved = try persistence.checkpoint(activityKey) {
                    guard saved.orderedSnapshots == snapshots else { state.contentChanged = true; state.isLoading = false; loaded = true; return }
                    let attempts = try persistence.attempts().filter { $0.sessionID == saved.sessionID }
                    guard snapshots.indices.contains(saved.position) else { throw ExerciseHistoryError.invalidRecord }
                    var selected: [String] = []
                    if let id = saved.revealedAttemptID {
                        guard let attempt = attempts.first(where: { $0.id == id }), attempt.snapshot == snapshots[saved.position], case .orderedTokens(let ids) = attempt.response else { throw ExerciseHistoryError.invalidRecord }
                        selected = ids; state.outcome = attempt.outcome
                    }
                    sessionID = saved.sessionID; state.position = saved.position; state.selectedIDs = selected
                    state.isRevealed = saved.revealedAttemptID != nil
                    state.correctCount = attempts.filter { $0.outcome == .correct }.count
                } else if current != nil {
                    pendingCheckpoint = pendingCheckpoint ?? checkpoint(position: 0)
                    try persistence.save(pendingCheckpoint!)
                }
                loaded = true; state.isLoading = false
            case .append(let id):
                guard canEdit, current?.metadata?.tokens.contains(where: { $0.id == id }) == true, !state.selectedIDs.contains(id) else { return }
                state.selectedIDs.append(id)
            case .remove(let id): guard canEdit else { return }; state.selectedIDs.removeAll { $0 == id }
            case .undo: guard canEdit else { return }; _ = state.selectedIDs.popLast()
            case .clear: guard canEdit else { return }; state.selectedIDs = []
            case .check:
                guard pendingAttempt != nil || canCheck, let current, let metadata = current.metadata else { return }
                let attempt = pendingAttempt ?? ExerciseAttempt(sessionID: sessionID, snapshot: current, response: .orderedTokens(state.selectedIDs), outcome: SentenceOrderPolicy.matches(state.selectedIDs, tokens: metadata.tokens, acceptedOrders: metadata.acceptedOrders) ? .correct : .incorrect, submittedAt: Date())
                pendingAttempt = attempt
                pendingCheckpoint = pendingCheckpoint ?? checkpoint(position: state.position, revealed: attempt.id)
                try persistence.record(attempt, pendingCheckpoint!)
                state.isRevealed = true; state.outcome = attempt.outcome
                if attempt.outcome == .correct { state.correctCount += 1 }
                pendingAttempt = nil
            case .next, .finish:
                guard state.isRevealed, current != nil else { return }
                if state.position + 1 == snapshots.count {
                    try persistence.finish(activityKey, sessionID); state.isComplete = true
                } else {
                    if case .finish = action { return }
                    pendingCheckpoint = pendingCheckpoint ?? checkpoint(position: state.position + 1)
                    try persistence.save(pendingCheckpoint!)
                    state.position += 1; state.selectedIDs = []; state.isRevealed = false; state.outcome = nil
                }
            case .restart:
                guard !snapshots.isEmpty, !state.hasInvalidContent else { return }
                pendingCheckpoint = pendingCheckpoint ?? checkpoint(position: 0, session: UUID())
                try persistence.save(pendingCheckpoint!)
                sessionID = pendingCheckpoint!.sessionID
                state = State(total: snapshots.count); loaded = true; pendingAttempt = nil
            case .retry: break
            }
            pendingAction = nil; pendingCheckpoint = nil; state.errorMessage = nil
        } catch {
            state.isLoading = false; pendingAction = action
            state.errorMessage = "Your sentence practice couldn't be opened or saved. Retry, or exit and return later."
        }
    }
    struct State {
        var position = 0
        var selectedIDs: [String] = []
        var isRevealed = false
        var outcome: ExerciseOutcome?
        var correctCount = 0
        var total = 0
        var contentChanged = false
        var hasInvalidContent = false
        var isLoading = false
        var isComplete = false
        var errorMessage: String?
    }
    enum Action: Equatable {
        case load, append(String), remove(String), undo, clear, check, next, finish, retry, restart
        var isPersistenceAction: Bool {
            switch self { case .load, .check, .next, .finish, .restart, .retry: return true; default: return false }
        }
    }
}
