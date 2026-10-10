import Foundation

public enum ExerciseHistoryValidator {
    public static func validateSnapshot(_ snapshot: ExerciseSnapshot) throws {
        guard validText(snapshot.id, max: 256), snapshot.revision > 0,
              validText(snapshot.prompt), snapshot.explanation.count <= 20_000,
              snapshot.choices.count <= 100, snapshot.acceptedAnswers.count <= 100,
              snapshot.choices.allSatisfy({ validText($0) }), snapshot.acceptedAnswers.allSatisfy({ validText($0, max: 500) }),
              snapshot.fingerprint == snapshot.computedFingerprint else { throw ExerciseHistoryError.invalidRecord }
        switch snapshot.questionKind {
        case .choice:
            guard snapshot.choices.count >= 2, let index = snapshot.correctIndex, snapshot.choices.indices.contains(index), snapshot.acceptedAnswers.isEmpty else { throw ExerciseHistoryError.invalidRecord }
        case .meaningSelfRated:
            guard snapshot.correctIndex == nil, snapshot.choices.isEmpty, snapshot.acceptedAnswers.isEmpty else { throw ExerciseHistoryError.invalidRecord }
        case .kanaReading, .romanization, .listeningReading:
            guard snapshot.correctIndex == nil, snapshot.choices.isEmpty, !snapshot.acceptedAnswers.isEmpty else { throw ExerciseHistoryError.invalidRecord }
        }
    }
    public static func validateAttempt(_ attempt: ExerciseAttempt) throws {
        try validateSnapshot(attempt.snapshot)
        guard attempt.submittedAt.timeIntervalSince1970.isFinite else { throw ExerciseHistoryError.invalidRecord }
        let correct: Bool
        switch (attempt.snapshot.questionKind, attempt.response) {
        case (.choice, .choice(let index)):
            guard attempt.snapshot.choices.indices.contains(index) else { throw ExerciseHistoryError.invalidRecord }
            correct = index == attempt.snapshot.correctIndex
        case (.meaningSelfRated, .selfRating):
            guard attempt.outcome == .selfRated else { throw ExerciseHistoryError.invalidRecord }; return
        case (.kanaReading, .text(let text)), (.romanization, .text(let text)), (.listeningReading, .text(let text)):
            guard validText(text, max: 500) else { throw ExerciseHistoryError.invalidRecord }
            correct = ExerciseAnswerNormalizer.matches(text, accepted: attempt.snapshot.acceptedAnswers, kind: attempt.snapshot.questionKind)
        default: throw ExerciseHistoryError.invalidRecord
        }
        guard attempt.outcome == (correct ? .correct : .incorrect) else { throw ExerciseHistoryError.invalidRecord }
    }
    public static func validateCheckpoint(_ checkpoint: ExerciseCheckpoint, attempts: [ExerciseAttempt]) throws {
        guard validText(checkpoint.activityKey, max: 256), checkpoint.updatedAt.timeIntervalSince1970.isFinite,
              !checkpoint.orderedSnapshots.isEmpty, checkpoint.orderedSnapshots.count <= 1_000,
              checkpoint.orderedSnapshots.indices.contains(checkpoint.position),
              Set(checkpoint.orderedSnapshots.map(\.fingerprint)).count == checkpoint.orderedSnapshots.count else { throw ExerciseHistoryError.invalidRecord }
        try checkpoint.orderedSnapshots.forEach(validateSnapshot)
        if let id = checkpoint.revealedAttemptID {
            guard let attempt = attempts.first(where: { $0.id == id }), attempt.sessionID == checkpoint.sessionID,
                  attempt.snapshot == checkpoint.orderedSnapshots[checkpoint.position], attempt.submittedAt <= checkpoint.updatedAt else { throw ExerciseHistoryError.invalidRecord }
        }
    }
    public static func validate(attempts: [ExerciseAttempt], checkpoints: [ExerciseCheckpoint], reviewRatingEvents: [ReviewRatingEvent] = []) throws {
        guard attempts.count <= 10_000, checkpoints.count <= 100, reviewRatingEvents.count <= 10_000,
              Set(attempts.map(\.id)).count == attempts.count, Set(checkpoints.map(\.activityKey)).count == checkpoints.count,
              Set(reviewRatingEvents.map(\.actionID)).count == reviewRatingEvents.count else { throw ExerciseHistoryError.invalidRecord }
        try attempts.forEach(validateAttempt)
        try checkpoints.forEach { try validateCheckpoint($0, attempts: attempts) }
        try reviewRatingEvents.forEach(validateReviewRatingEvent)
    }
    public static func validateReviewRatingEvent(_ event: ReviewRatingEvent) throws {
        guard validText(event.id.id, max: 256), event.submittedAt.timeIntervalSince1970.isFinite else { throw ExerciseHistoryError.invalidRecord }
    }
    private static func validText(_ text: String, max: Int = 20_000) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= max }
}
