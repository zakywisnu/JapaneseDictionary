import Foundation
import Observation
import DataKit
import DomainKit

@MainActor
@Observable
final class RecallSessionViewModel {
    let questions: [RecallQuestion]
    let activityKey: String
    let isListening: Bool
    let pronunciation: PronunciationService
    private let persistence: ExercisePersistence
    private var sessionID = UUID()
    private var pendingAttempt: ExerciseAttempt?
    private var pendingAction: Action?
    private var loaded = false
    private var playbackRequested = false
    private(set) var state = State()
    init(questions: [RecallQuestion], activityKey: String, isListening: Bool = false, persistence: ExercisePersistence, pronunciation: PronunciationService? = nil) {
        self.questions = questions; self.activityKey = activityKey; self.isListening = isListening
        self.persistence = persistence; self.pronunciation = pronunciation ?? PronunciationService()
        state.total = questions.count
    }
    var current: RecallQuestion? { questions.indices.contains(state.position) && !state.isComplete ? questions[state.position] : nil }
    var canSubmit: Bool {
        loaded && !state.contentChanged && !state.isRevealed && pendingAttempt == nil && (!isListening || (state.heardPlayback && playbackFailure == nil)) && !state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && state.draft.count <= 500
    }
    var playbackFailure: String? {
        switch pronunciation.state {
        case .unavailable: return "A Japanese voice isn't available on this iPhone. Check voice availability, or choose typed practice."
        case .failed(let message): return message
        default: return nil
        }
    }
    var promptVisible: Bool { !isListening || state.isRevealed || state.isAnswerShown }
    private func checkpoint(position: Int, revealed: UUID? = nil, session: UUID? = nil) -> ExerciseCheckpoint {
        ExerciseCheckpoint(activityKey: activityKey, sessionID: session ?? sessionID, orderedSnapshots: questions.map(\.snapshot), position: position, revealedAttemptID: revealed, updatedAt: Date())
    }
    func send(_ action: Action) {
        if case .retry = action { guard let pendingAction else { return }; send(pendingAction); return }
        do {
            switch action {
            case .load:
                guard !loaded else { return }
                state.isLoading = true
                if let saved = try persistence.checkpoint(activityKey) {
                    guard saved.orderedSnapshots.map(\.fingerprint) == questions.map({ $0.snapshot.fingerprint }) else {
                        state.contentChanged = true; state.isLoading = false; loaded = true; return
                    }
                    let attempts = try persistence.attempts().filter { $0.sessionID == saved.sessionID }
                    sessionID = saved.sessionID; state.position = saved.position
                    state.correctCount = attempts.filter { $0.outcome == .correct }.count
                    state.checkedCount = attempts.filter { $0.outcome != .selfRated }.count
                    state.selfRatedCount = attempts.filter { $0.outcome == .selfRated }.count
                    if let id = saved.revealedAttemptID, let attempt = attempts.first(where: { $0.id == id }) {
                        state.isRevealed = true; state.isAnswerShown = true; state.outcome = attempt.outcome
                        switch attempt.response { case .text(let value): state.draft = value; case .choice(let index): state.selectedIndex = index; case .selfRating(let value): state.remembered = value }
                    }
                } else if !questions.isEmpty { try persistence.save(checkpoint(position: 0)) }
                state.isLoading = false; loaded = true
            case .draft(let value):
                guard !state.isRevealed, pendingAttempt == nil else { return }
                state.draft = value
                return
            case .play:
                guard let reading = current?.suppliedReading else { return }
                state.heardPlayback = false; playbackRequested = true
                pronunciation.listen(reading: reading)
                if playbackFailure != nil { playbackRequested = false }
                else if pronunciation.state == .idle { state.heardPlayback = true; playbackRequested = false }
                return
            case .playbackChanged:
                if pronunciation.state == .idle, playbackRequested { state.heardPlayback = true; playbackRequested = false }
                else if playbackFailure != nil { state.heardPlayback = false; playbackRequested = false }
                return
            case .cancel:
                playbackRequested = false; state.heardPlayback = false; pronunciation.stop(); return
            case .reveal:
                guard loaded, pendingAttempt == nil, !state.contentChanged, !state.isRevealed, !isListening || (state.heardPlayback && playbackFailure == nil) else { return }
                state.isAnswerShown = true; return
            case .submit:
                guard let question = current, pendingAttempt != nil || canSubmit, !state.isAnswerShown else { return }
                let kind = question.snapshot.questionKind
                guard kind == .kanaReading || kind == .romanization || kind == .listeningReading else { return }
                try record(response: .text(state.draft), outcome: ExerciseAnswerNormalizer.matches(state.draft, accepted: question.snapshot.acceptedAnswers, kind: kind) ? .correct : .incorrect)
            case .choose(let index):
                guard loaded, !state.contentChanged, !state.isRevealed, let question = current, question.snapshot.questionKind == .choice, question.snapshot.choices.indices.contains(index), pendingAttempt == nil || state.selectedIndex == index else { return }
                state.selectedIndex = index
                try record(response: .choice(index), outcome: index == question.snapshot.correctIndex ? .correct : .incorrect)
            case .rate(let remembered):
                guard current?.snapshot.questionKind == .meaningSelfRated, state.isAnswerShown, !state.isRevealed, pendingAttempt == nil || state.remembered == remembered else { return }
                state.remembered = remembered
                try record(response: .selfRating(remembered), outcome: .selfRated)
            case .next:
                guard state.isRevealed || (state.isAnswerShown && current?.snapshot.questionKind != .meaningSelfRated) else { return }
                playbackRequested = false; pronunciation.stop()
                if state.position + 1 == questions.count {
                    try persistence.finish(activityKey, sessionID); state.isComplete = true
                } else {
                    try persistence.save(checkpoint(position: state.position + 1))
                    state.position += 1; state.draft = ""; state.isRevealed = false; state.isAnswerShown = false
                    state.outcome = nil; state.selectedIndex = nil; state.remembered = nil; state.heardPlayback = false
                }
            case .restart:
                let next = UUID()
                if !questions.isEmpty { try persistence.save(checkpoint(position: 0, session: next)) }
                sessionID = next; pendingAttempt = nil; playbackRequested = false; pronunciation.stop()
                state = State(total: questions.count); state.isLoading = false; loaded = true
            case .retry: break
            }
            pendingAction = nil; state.error = nil
        } catch {
            state.isLoading = false; pendingAction = action
            state.error = "Your answer or session couldn't be saved or opened. Retry, or exit and return later."
        }
    }
    private func record(response: ExerciseResponse, outcome: ExerciseOutcome) throws {
        guard let question = current else { return }
        let attempt = pendingAttempt ?? ExerciseAttempt(sessionID: sessionID, snapshot: question.snapshot, response: response, outcome: outcome, submittedAt: Date())
        pendingAttempt = attempt
        try persistence.record(attempt, checkpoint(position: state.position, revealed: attempt.id))
        pendingAttempt = nil; state.isRevealed = true; state.isAnswerShown = true; state.outcome = attempt.outcome
        if attempt.outcome == .correct { state.correctCount += 1 }
        if attempt.outcome == .selfRated { state.selfRatedCount += 1 } else { state.checkedCount += 1 }
    }
    struct State {
        var position = 0
        var total = 0
        var draft = ""
        var selectedIndex: Int?
        var remembered: Bool?
        var isLoading = true
        var isComplete = false
        var isRevealed = false
        var isAnswerShown = false
        var heardPlayback = false
        var contentChanged = false
        var error: String?
        var outcome: ExerciseOutcome?
        var correctCount = 0
        var checkedCount = 0
        var selfRatedCount = 0
    }
    enum Action { case load, draft(String), play, playbackChanged, cancel, reveal, submit, choose(Int), rate(Bool), next, restart, retry }
}
