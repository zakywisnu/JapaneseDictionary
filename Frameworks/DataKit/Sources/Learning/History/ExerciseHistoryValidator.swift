import Foundation

public enum ExerciseHistoryValidator {
    public static func validateSnapshot(_ snapshot: ExerciseSnapshot) throws {
        guard validText(snapshot.id, max: 256), snapshot.revision > 0,
              validText(snapshot.prompt), snapshot.explanation.count <= 20_000,
              snapshot.choices.count <= 100, snapshot.acceptedAnswers.count <= 100,
              snapshot.choices.allSatisfy({ validText($0) }), snapshot.acceptedAnswers.allSatisfy({ validText($0, max: 500) }),
              snapshot.fingerprint == snapshot.computedFingerprint else { throw ExerciseHistoryError.invalidRecord }
        if let metadata = snapshot.metadata {
            try validateMetadata(metadata, kind: snapshot.questionKind)
            if let review = metadata.review { try validatePracticeReview(review, hash: snapshot.computedReviewHash) }
        }
        switch snapshot.questionKind {
        case .choice, .listeningComprehension:
            guard snapshot.choices.count >= 2, let index = snapshot.correctIndex, snapshot.choices.indices.contains(index), snapshot.acceptedAnswers.isEmpty else { throw ExerciseHistoryError.invalidRecord }
        case .meaningSelfRated:
            guard snapshot.correctIndex == nil, snapshot.choices.isEmpty, snapshot.acceptedAnswers.isEmpty else { throw ExerciseHistoryError.invalidRecord }
        case .kanaReading, .romanization, .listeningReading, .conjugation:
            guard snapshot.correctIndex == nil, snapshot.choices.isEmpty, !snapshot.acceptedAnswers.isEmpty else { throw ExerciseHistoryError.invalidRecord }
        case .sentenceOrder:
            guard let metadata = snapshot.metadata, !metadata.tokens.isEmpty, !metadata.acceptedOrders.isEmpty,
                  snapshot.correctIndex == nil, snapshot.choices.isEmpty, snapshot.acceptedAnswers.isEmpty else { throw ExerciseHistoryError.invalidRecord }
        }
        if snapshot.questionKind == .listeningComprehension {
            guard let metadata = snapshot.metadata, let stimulus = metadata.stimulus, let reading = metadata.suppliedReading,
                  validText(stimulus), validText(reading) else { throw ExerciseHistoryError.invalidRecord }
        }
        if [.conjugation, .listeningComprehension].contains(snapshot.questionKind), snapshot.metadata == nil { throw ExerciseHistoryError.invalidRecord }
    }
    private static func validateMetadata(_ metadata: PracticeMetadata, kind: ExerciseQuestionKind) throws {
        guard metadata.schemaVersion == 1, metadata.activityKind == kind.rawValue, validText(metadata.topicID, max: 256),
              validText(metadata.source), [metadata.stimulus, metadata.suppliedReading, metadata.translation].compactMap({ $0 }).allSatisfy({ validText($0) }),
              metadata.tokens.count <= 40, metadata.acceptedOrders.count <= 20,
              Set(metadata.tokens.map(\.id)).count == metadata.tokens.count,
              metadata.tokens.allSatisfy({ validText($0.id, max: 256) && validText($0.text, max: 500) }) else { throw ExerciseHistoryError.invalidRecord }
        let ids = Set(metadata.tokens.map(\.id))
        guard metadata.acceptedOrders.allSatisfy({ $0.count == ids.count && Set($0) == ids }),
              kind == .sentenceOrder || (metadata.tokens.isEmpty && metadata.acceptedOrders.isEmpty) else { throw ExerciseHistoryError.invalidRecord }
    }
    public static func matchesOrderedTokens(_ response: [String], metadata: PracticeMetadata) -> Bool {
        guard response.count == metadata.tokens.count,
              Set(response) == Set(metadata.tokens.map(\.id)),
              Set(metadata.tokens.map(\.id)).count == metadata.tokens.count else { return false }
        let text = Dictionary(uniqueKeysWithValues: metadata.tokens.map { ($0.id, $0.text) })
        let rendered = response.compactMap { text[$0] }
        return metadata.acceptedOrders.contains { $0.compactMap { text[$0] } == rendered }
    }
    public static func validateAttempt(_ attempt: ExerciseAttempt) throws {
        try validateSnapshot(attempt.snapshot)
        guard attempt.snapshot.metadata?.assisted != true, attempt.submittedAt.timeIntervalSince1970.isFinite else { throw ExerciseHistoryError.invalidRecord }
        let correct: Bool
        switch (attempt.snapshot.questionKind, attempt.response) {
        case (.choice, .choice(let index)), (.listeningComprehension, .choice(let index)):
            guard attempt.snapshot.choices.indices.contains(index) else { throw ExerciseHistoryError.invalidRecord }
            correct = index == attempt.snapshot.correctIndex
        case (.meaningSelfRated, .selfRating):
            guard attempt.outcome == .selfRated else { throw ExerciseHistoryError.invalidRecord }; return
        case (.kanaReading, .text(let text)), (.romanization, .text(let text)), (.listeningReading, .text(let text)), (.conjugation, .text(let text)):
            guard validText(text, max: 500) else { throw ExerciseHistoryError.invalidRecord }
            correct = ExerciseAnswerNormalizer.matches(text, accepted: attempt.snapshot.acceptedAnswers, kind: attempt.snapshot.questionKind)
        case (.sentenceOrder, .orderedTokens(let ids)):
            guard let metadata = attempt.snapshot.metadata, ids.count == metadata.tokens.count,
                  Set(ids) == Set(metadata.tokens.map(\.id)) else { throw ExerciseHistoryError.invalidRecord }
            correct = matchesOrderedTokens(ids, metadata: metadata)
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
        guard validText(event.id.id, max: 256), event.contextID.map({ validText($0, max: 256) }) ?? true, event.submittedAt.timeIntervalSince1970.isFinite else { throw ExerciseHistoryError.invalidRecord }
    }
    private static func validText(_ text: String, max: Int = 20_000) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= max }
}
