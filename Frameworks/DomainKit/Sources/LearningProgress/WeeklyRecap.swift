import Foundation
import DataKit

public struct FirstAttemptKey: Hashable {
    public let sessionID: UUID
    public let fingerprint: String
    public init(sessionID: UUID, fingerprint: String) { self.sessionID = sessionID; self.fingerprint = fingerprint }
}
public enum WeeklyFocusDestination: Hashable {
    case topic(kind: ExerciseQuestionKind, id: String)
    case mistakes, starterPath, practice
}
public struct WeeklyFocus: Equatable {
    public let destination: WeeklyFocusDestination
    public let reason: String
    public init(destination: WeeklyFocusDestination, reason: String) { self.destination = destination; self.reason = reason }
}
public struct WeeklyTopic: Equatable {
    public let topicID: String
    public let kind: ExerciseQuestionKind
    public let sessions: Int
    public let latestMiss: Date
    public let available: Bool
}
public struct WeeklyComparableDelta: Equatable {
    public let current: LearningActivityCounts
    public let prior: LearningActivityCounts
    public var percentagePoints: Double { ((current.accuracy ?? 0) - (prior.accuracy ?? 0)) * 100 }
}
public struct WeeklyRecap: Equatable {
    public let currentInterval: DateInterval
    public let priorInterval: DateInterval
    public let priorRangeCaption: String
    public let practiceDays: Int
    public let rangeCaption: String
    public let firstAttemptCounts: [ExerciseQuestionKind: LearningActivityCounts]
    public let comparableDelta: [ExerciseQuestionKind: WeeklyComparableDelta]
    public let selfRatedCurrent: LearningActivityCounts
    public let selfRatedPrior: LearningActivityCounts
    public let recurringTopics: [WeeklyTopic]
    public let availableFocusIDs: Set<String>
    public let currentMistakes: Int
    public let currentActivityCount: Int
    public let focus: WeeklyFocus?
    public var hasCurrentActivity: Bool { currentActivityCount > 0 }
    public static let historyDisclosure = "Based on retained local history: up to 10,000 recent answers and review ratings. Earlier or removed records are unavailable. These counts describe practice, not mastery."
}
