import Foundation
import DataKit

public struct LearningActivityCounts: Equatable {
    public var submitted: Int
    public var correct: Int
    public var accuracy: Double? { submitted == 0 ? nil : Double(correct) / Double(submitted) }
    public init(submitted: Int = 0, correct: Int = 0) { self.submitted = submitted; self.correct = correct }
}
public enum LearningPathStepState: String, Equatable { case notStarted, attempted, completed, skipped, current }
public struct LearningPathStepStatus: Equatable {
    public var stepID: String
    public var title: String
    public var status: LearningPathStepState
    public init(stepID: String, title: String, status: LearningPathStepState) { self.stepID = stepID; self.title = title; self.status = status }
}
public struct LearningProgressSummary: Equatable {
    public var gradedCorrect = 0
    public var gradedTotal = 0
    public var selfRatedGotIt = 0
    public var selfRatedTotal = 0
    public var practiceDays = 0
    public var remainingMistakes = 0
    public var remainingMistakesByKind: [ExerciseQuestionKind: Int] = [:]
    public var choice = LearningActivityCounts()
    public var kanaReading = LearningActivityCounts()
    public var romanization = LearningActivityCounts()
    public var listeningReading = LearningActivityCounts()
    public var meaningSelfRatedSubmitted = 0
    public var meaningSelfRatedRemembered = 0
    public var distinctAttemptedContent = 0
    public var distinctSavedItemsPracticed = 0
    public var rangeStart: Date
    public var rangeEnd: Date
    public var timeZoneIdentifier: String
    public var rangeCaption: String
    public var reviewRecordedSince: Date?
    public var pathStepStatuses: [LearningPathStepStatus] = []
    public var gradedAccuracy: Double? { gradedTotal == 0 ? nil : Double(gradedCorrect) / Double(gradedTotal) }
    public static func calculate(attempts: [ExerciseAttempt], events: [ReviewRatingEvent], days: Int, now: Date, calendar: Calendar, activities: [PracticeActivity] = [], pathProgress: LearningPathProgress? = nil, pathSteps: [LearningPathStep] = []) -> Self {
        let boundedDays = max(1, min(days, 30))
        let start = calendar.date(byAdding: .day, value: -(boundedDays - 1), to: calendar.startOfDay(for: now)) ?? calendar.startOfDay(for: now)
        let inRange: (Date) -> Bool = { $0.timeIntervalSince1970.isFinite && $0 >= start && $0 <= now }
        // Resolve duplicate IDs deterministically before counting any numerator or denominator.
        let allAttempts = uniqueAttempts(attempts.filter { $0.submittedAt.timeIntervalSince1970.isFinite && $0.submittedAt <= now })
        let allEvents = uniqueEvents(events.filter { $0.submittedAt.timeIntervalSince1970.isFinite && $0.submittedAt <= now })
        let submitted = allAttempts.filter { inRange($0.submittedAt) }
        let graded = submitted.filter { $0.outcome != .selfRated }
        var keys = Set<String>()
        // A first Again outside the window must not turn a later Got it into first-try success.
        let firstRatings = allEvents.filter { keys.insert($0.sessionID.uuidString + ":" + $0.id.key).inserted }.filter { inRange($0.submittedAt) }
        var activityKeys = Set<String>()
        let activity = activities.filter { inRange($0.completedAt) && activityKeys.insert($0.key).inserted }
        let dates = submitted.map(\.submittedAt) + allEvents.filter { inRange($0.submittedAt) }.map(\.submittedAt) + activity.map(\.completedAt)
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "MMM d, yyyy"
        var result = Self(rangeStart: start, rangeEnd: now, timeZoneIdentifier: calendar.timeZone.identifier,
                          rangeCaption: "\(formatter.string(from: start)) – \(formatter.string(from: now)) (\(calendar.timeZone.identifier))",
                          reviewRecordedSince: allEvents.first?.submittedAt)
        result.gradedCorrect = graded.filter { $0.outcome == .correct }.count; result.gradedTotal = graded.count
        result.selfRatedGotIt = firstRatings.filter { !$0.again }.count; result.selfRatedTotal = firstRatings.count
        result.practiceDays = Set(dates.map { calendar.startOfDay(for: $0) }).count
        let mistakes = ExerciseHistoryQuery.latestMistakes(allAttempts)
        result.remainingMistakes = mistakes.count
        result.remainingMistakesByKind = Dictionary(grouping: mistakes, by: { $0.snapshot.questionKind }).mapValues(\.count)
        func counts(_ kind: ExerciseQuestionKind) -> LearningActivityCounts {
            let values = graded.filter { $0.snapshot.questionKind == kind }
            return .init(submitted: values.count, correct: values.filter { $0.outcome == .correct }.count)
        }
        result.choice = counts(.choice); result.kanaReading = counts(.kanaReading)
        result.romanization = counts(.romanization); result.listeningReading = counts(.listeningReading)
        let meaning = submitted.filter { $0.snapshot.questionKind == .meaningSelfRated && $0.outcome == .selfRated }
        result.meaningSelfRatedSubmitted = meaning.count
        result.meaningSelfRatedRemembered = meaning.filter { $0.response == .selfRating(true) }.count
        result.distinctAttemptedContent = Set(submitted.map { $0.snapshot.fingerprint }).count
        result.distinctSavedItemsPracticed = Set(activity.map(\.studyID)).count
        result.pathStepStatuses = pathSteps.map { step in
            let status: LearningPathStepState
            if pathProgress?.skippedStepIDs.contains(step.id) == true { status = .skipped }
            else if pathProgress?.isComplete(step) == true { status = .completed }
            else if pathProgress?.currentStepID == step.id { status = .current }
            else if allAttempts.contains(where: { $0.snapshot.revision == step.revision && step.requiredContentIDs.contains($0.snapshot.id) }) { status = .attempted }
            else { status = .notStarted }
            return .init(stepID: step.id, title: step.title, status: status)
        }
        return result
    }
    private static func uniqueAttempts(_ values: [ExerciseAttempt]) -> [ExerciseAttempt] {
        var ids = Set<UUID>()
        return values.sorted {
            if $0.submittedAt != $1.submittedAt { return $0.submittedAt < $1.submittedAt }
            if $0.id != $1.id { return $0.id.uuidString < $1.id.uuidString }
            return $0.snapshot.fingerprint < $1.snapshot.fingerprint
        }.filter { ids.insert($0.id).inserted }
    }
    private static func uniqueEvents(_ values: [ReviewRatingEvent]) -> [ReviewRatingEvent] {
        var ids = Set<UUID>()
        return values.sorted {
            if $0.submittedAt != $1.submittedAt { return $0.submittedAt < $1.submittedAt }
            if $0.actionID != $1.actionID { return $0.actionID.uuidString < $1.actionID.uuidString }
            if $0.id.key != $1.id.key { return $0.id.key < $1.id.key }
            return $0.again && !$1.again
        }.filter { ids.insert($0.actionID).inserted }
    }
}
public struct LearningProgressUseCase {
    private let loadAttempts: () throws -> [ExerciseAttempt]
    private let loadEvents: () throws -> [ReviewRatingEvent]
    private let loadActivities: () throws -> [PracticeActivity]
    private let loadPathProgress: () throws -> LearningPathProgress?
    private let pathSteps: [LearningPathStep]
    public init(loadAttempts: @escaping () throws -> [ExerciseAttempt], loadEvents: @escaping () throws -> [ReviewRatingEvent], loadActivities: @escaping () throws -> [PracticeActivity] = { [] }, loadPathProgress: @escaping () throws -> LearningPathProgress? = { nil }, pathSteps: [LearningPathStep] = []) {
        self.loadAttempts = loadAttempts; self.loadEvents = loadEvents; self.loadActivities = loadActivities; self.loadPathProgress = loadPathProgress; self.pathSteps = pathSteps
    }
    public func execute(days: Int, now: Date, calendar: Calendar) throws -> LearningProgressSummary {
        .calculate(attempts: try loadAttempts(), events: try loadEvents(), days: days, now: now, calendar: calendar, activities: try loadActivities(), pathProgress: try loadPathProgress(), pathSteps: pathSteps)
    }
}
