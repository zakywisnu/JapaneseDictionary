import Foundation
import CryptoKit
import SwiftData

public enum ExerciseQuestionKind: String, Codable, Hashable { case choice, kanaReading, romanization, listeningReading, meaningSelfRated }
public struct ExerciseSnapshot: Codable, Hashable {
    public var id: String
    public var revision: Int
    public var fingerprint: String
    public var questionKind: ExerciseQuestionKind
    public var prompt: String
    public var choices: [String]
    public var correctIndex: Int?
    public var acceptedAnswers: [String]
    public var explanation: String
    public init(id: String, revision: Int, questionKind: ExerciseQuestionKind, prompt: String, choices: [String] = [], correctIndex: Int? = nil, acceptedAnswers: [String] = [], explanation: String) {
        self.id = id; self.revision = revision; self.questionKind = questionKind; self.prompt = prompt
        self.choices = choices; self.correctIndex = correctIndex; self.acceptedAnswers = acceptedAnswers; self.explanation = explanation
        fingerprint = ""; fingerprint = computedFingerprint
    }
    public var computedFingerprint: String {
        var copy = self; copy.fingerprint = ""
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: (try? encoder.encode(copy)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }
}
public enum ExerciseResponse: Codable, Hashable { case choice(Int), text(String), selfRating(Bool) }
public enum ExerciseOutcome: String, Codable, Hashable { case correct, incorrect, selfRated }
public struct ExerciseAttempt: Codable, Hashable {
    public var id: UUID
    public var sessionID: UUID
    public var snapshot: ExerciseSnapshot
    public var response: ExerciseResponse
    public var outcome: ExerciseOutcome
    public var submittedAt: Date
    public init(id: UUID = UUID(), sessionID: UUID, snapshot: ExerciseSnapshot, response: ExerciseResponse, outcome: ExerciseOutcome, submittedAt: Date) {
        self.id = id; self.sessionID = sessionID; self.snapshot = snapshot; self.response = response; self.outcome = outcome; self.submittedAt = submittedAt
    }
}
public struct ExerciseCheckpoint: Codable, Hashable {
    public var activityKey: String
    public var sessionID: UUID
    public var orderedSnapshots: [ExerciseSnapshot]
    public var position: Int
    public var revealedAttemptID: UUID?
    public var updatedAt: Date
    public init(activityKey: String, sessionID: UUID, orderedSnapshots: [ExerciseSnapshot], position: Int, revealedAttemptID: UUID? = nil, updatedAt: Date) {
        self.activityKey = activityKey; self.sessionID = sessionID; self.orderedSnapshots = orderedSnapshots; self.position = position; self.revealedAttemptID = revealedAttemptID; self.updatedAt = updatedAt
    }
}
@Model public final class ExerciseAttemptModel {
    @Attribute(.unique) public var id: UUID
    public var payload: Data
    public init(value: ExerciseAttempt) throws { id = value.id; payload = try JSONEncoder().encode(value) }
    public func value() throws -> ExerciseAttempt {
        let value = try JSONDecoder().decode(ExerciseAttempt.self, from: payload)
        guard value.id == id else { throw ExerciseHistoryError.invalidRecord }
        try ExerciseHistoryValidator.validateAttempt(value)
        return value
    }
}
@Model public final class ExerciseCheckpointModel {
    @Attribute(.unique) public var activityKey: String
    public var payload: Data
    public init(value: ExerciseCheckpoint) throws { activityKey = value.activityKey; payload = try JSONEncoder().encode(value) }
    public func value() throws -> ExerciseCheckpoint {
        let value = try JSONDecoder().decode(ExerciseCheckpoint.self, from: payload)
        guard value.activityKey == activityKey else { throw ExerciseHistoryError.invalidRecord }
        return value
    }
    public func apply(_ value: ExerciseCheckpoint) throws { payload = try JSONEncoder().encode(value) }
}
public enum ExerciseHistoryError: Error, LocalizedError {
    case invalidRecord, conflictingID, historyFull
    public var errorDescription: String? {
        switch self {
        case .invalidRecord: return "This exercise record is invalid. Return to Learning and start a new session."
        case .conflictingID: return "This answer already has different saved content. Return to Learning and resume the saved session."
        case .historyFull: return "History is full of unfinished sessions. Finish or restart an unfinished session, then retry saving this answer."
        }
    }
}
public enum ExerciseHistoryQuery {
    public static func latestMistakes(_ attempts: [ExerciseAttempt]) -> [ExerciseAttempt] {
        var latest: [String: ExerciseAttempt] = [:]
        for attempt in attempts.sorted(by: ordered) where attempt.outcome != .selfRated { latest[attempt.snapshot.fingerprint] = attempt }
        return latest.values.filter { $0.outcome == .incorrect }.sorted { ordered($1, $0) }
    }
    private static func ordered(_ a: ExerciseAttempt, _ b: ExerciseAttempt) -> Bool {
        a.submittedAt == b.submittedAt ? a.id.uuidString < b.id.uuidString : a.submittedAt < b.submittedAt
    }
}
