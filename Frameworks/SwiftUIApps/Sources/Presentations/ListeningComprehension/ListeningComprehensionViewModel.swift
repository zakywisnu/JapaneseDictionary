import Foundation
import Observation
import DataKit

@MainActor @Observable final class ListeningComprehensionViewModel {
    struct State {
        var loading = true
        var position = 0
        var selected: Int?
        var answered = false
        var correct: Bool?
        var checked = 0
        var matched = 0
        var heardPlayback = false
        var transcriptVisible = false
        var isComplete = false
        var error: String?
        var contentChanged = false
        var assisted = false
    }
    enum Action: Equatable { case load, play, playbackChanged, stop, choose(Int), check, revealTranscript, next, retry, restart, cancel }
    private(set) var state = State()
    private(set) var snapshots: [ExerciseSnapshot]
    let activityKey: String
    let pronunciation: PronunciationService
    private let persistence: ExercisePersistence
    private let initial: [ExerciseSnapshot]
    private let now: () -> Date
    private var sessionID = UUID()
    private var requestedPlayback = false
    private var pendingAction: Action?
    private var pendingAttempt: ExerciseAttempt?
    private var pendingCheckpoint: ExerciseCheckpoint?
    init(snapshots: [ExerciseSnapshot], activityKey: String, persistence: ExercisePersistence, pronunciation: PronunciationService? = nil, now: @escaping () -> Date = Date.init) {
        self.snapshots = snapshots
        initial = snapshots.map { snapshot in
            var copy = snapshot
            if copy.metadata?.assisted == true { copy.metadata?.assisted = false; copy.fingerprint = copy.computedFingerprint }
            return copy
        }
        self.activityKey = activityKey; self.persistence = persistence
        self.pronunciation = pronunciation ?? PronunciationService(); self.now = now
    }
    var current: ExerciseSnapshot? { !state.isComplete && snapshots.indices.contains(state.position) ? snapshots[state.position] : nil }
    var canCheck: Bool { !state.loading && !state.contentChanged && !state.answered && state.selected != nil && state.heardPlayback && state.error == nil && playbackError == nil }
    var playbackError: String? {
        switch pronunciation.state { case .unavailable: return "A Japanese voice is unavailable. Check again or choose another activity."
        case .failed(let message): return message
        default: return nil }
    }
    private func checkpoint(revealed: UUID? = nil) -> ExerciseCheckpoint {
        .init(activityKey: activityKey, sessionID: sessionID, orderedSnapshots: snapshots, position: state.position, revealedAttemptID: revealed, updatedAt: now())
    }
    func send(_ action: Action) {
        if case .retry = action { guard let pendingAction else { return }; state.error = nil; if case .load = pendingAction { state.loading = true }; send(pendingAction); return }
        if let pendingAction, pendingAction != action {
            switch action { case .cancel, .stop: break; default: return }
        }
        do {
            switch action {
            case .load:
                guard state.loading else { return }
                if let saved = try persistence.checkpoint(activityKey) {
                    let authored: (ExerciseSnapshot) -> String = { value in
                        var copy = value; copy.metadata?.assisted = false; copy.fingerprint = copy.computedFingerprint; return copy.fingerprint
                    }
                    guard saved.orderedSnapshots.map(authored) == initial.map(authored) else {
                        state.loading = false; state.contentChanged = true; return
                    }
                    snapshots = saved.orderedSnapshots; sessionID = saved.sessionID; state.position = saved.position
                    let attempts = try persistence.attempts().filter { $0.sessionID == sessionID }
                    state.checked = attempts.count; state.matched = attempts.filter { $0.outcome == .correct }.count
                    if let id = saved.revealedAttemptID, let attempt = attempts.first(where: { $0.id == id }), case .choice(let index) = attempt.response {
                        state.selected = index; state.answered = true; state.correct = attempt.outcome == .correct
                    }
                    state.assisted = current?.metadata?.assisted == true
                    state.transcriptVisible = state.assisted
                } else if !snapshots.isEmpty {
                    let saved = pendingCheckpoint ?? checkpoint()
                    pendingCheckpoint = saved; try persistence.save(saved)
                }
                state.loading = false
            case .play:
                guard !state.loading, !state.contentChanged, let reading = current?.metadata?.suppliedReading else { return }
                state.heardPlayback = false; requestedPlayback = true; pronunciation.listen(reading: reading)
                if playbackError != nil { requestedPlayback = false }
                else if pronunciation.state == .idle { state.heardPlayback = true; requestedPlayback = false }
                return
            case .playbackChanged:
                if requestedPlayback, pronunciation.state == .idle { state.heardPlayback = true; requestedPlayback = false }
                else if playbackError != nil { requestedPlayback = false; state.heardPlayback = false }
                return
            case .stop, .cancel:
                requestedPlayback = false; state.heardPlayback = false; pronunciation.stop(); return
            case .choose(let index):
                guard !state.loading, !state.contentChanged, !state.answered, let current, current.choices.indices.contains(index), pendingAttempt == nil else { return }
                state.selected = index; return
            case .check:
                guard let current, let selected = state.selected, pendingAttempt != nil || canCheck else { return }
                if current.metadata?.assisted == true {
                    state.answered = true; state.correct = nil
                } else {
                    let attempt = pendingAttempt ?? ExerciseAttempt(sessionID: sessionID, snapshot: current, response: .choice(selected), outcome: selected == current.correctIndex ? .correct : .incorrect, submittedAt: now())
                    pendingAttempt = attempt
                    let saved = pendingCheckpoint ?? checkpoint(revealed: attempt.id); pendingCheckpoint = saved
                    try persistence.record(attempt, saved)
                    state.answered = true; state.correct = attempt.outcome == .correct
                    state.checked += 1; if attempt.outcome == .correct { state.matched += 1 }
                }
            case .revealTranscript:
                guard !state.loading, !state.contentChanged, let current else { return }
                var saved: ExerciseCheckpoint
                if let pendingCheckpoint { saved = pendingCheckpoint }
                else {
                    let revealed = state.answered ? try persistence.checkpoint(activityKey)?.revealedAttemptID : nil
                    saved = checkpoint(revealed: revealed)
                }
                if pendingCheckpoint == nil {
                    let first = state.answered ? state.position + 1 : state.position
                    if first < snapshots.count {
                        for index in first..<snapshots.count where snapshots[index].metadata?.stimulus == current.metadata?.stimulus {
                            saved.orderedSnapshots[index].metadata?.assisted = true
                            saved.orderedSnapshots[index].fingerprint = saved.orderedSnapshots[index].computedFingerprint
                        }
                    }
                }
                pendingCheckpoint = saved; try persistence.save(saved)
                snapshots = saved.orderedSnapshots; state.transcriptVisible = true; state.assisted = self.current?.metadata?.assisted == true
            case .next:
                guard state.answered else { return }
                requestedPlayback = false; pronunciation.stop()
                if state.position + 1 == snapshots.count { try persistence.finish(activityKey, sessionID); state.isComplete = true }
                else {
                    var saved = pendingCheckpoint ?? checkpoint(); saved.position = state.position + 1; saved.revealedAttemptID = nil
                    pendingCheckpoint = saved; try persistence.save(saved)
                    let samePassage = snapshots[saved.position].metadata?.stimulus == current?.metadata?.stimulus
                    let heard = state.heardPlayback && samePassage
                    state.position = saved.position; state.selected = nil; state.answered = false; state.correct = nil
                    state.assisted = self.current?.metadata?.assisted == true; state.transcriptVisible = state.assisted; state.heardPlayback = heard
                }
            case .restart:
                let saved = pendingCheckpoint ?? ExerciseCheckpoint(activityKey: activityKey, sessionID: UUID(), orderedSnapshots: initial, position: 0, updatedAt: now())
                pendingCheckpoint = saved
                if !initial.isEmpty { try persistence.save(saved) }
                requestedPlayback = false; pronunciation.stop(); sessionID = saved.sessionID; snapshots = initial; state = State(); state.loading = false
            case .retry: break
            }
            pendingAction = nil; pendingAttempt = nil; pendingCheckpoint = nil; state.error = nil
        } catch {
            state.loading = false; pendingAction = action
            state.error = "Your answer or practice position couldn't be saved or opened. Retry, or exit and return later."
        }
    }
}
