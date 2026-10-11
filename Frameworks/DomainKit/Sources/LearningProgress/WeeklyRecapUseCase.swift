import Foundation
import DataKit

public struct WeeklyRecapUseCase {
    private let loadAttempts: () throws -> [ExerciseAttempt]
    private let loadEvents: () throws -> [ReviewRatingEvent]
    private let loadPathProgress: () throws -> LearningPathProgress?
    private let availableTopics: () throws -> [String: ExerciseQuestionKind]
    public init(loadAttempts: @escaping () throws -> [ExerciseAttempt], loadEvents: @escaping () throws -> [ReviewRatingEvent], loadPathProgress: @escaping () throws -> LearningPathProgress? = { nil }, availableTopics: @escaping () throws -> [String: ExerciseQuestionKind] = { [:] }) {
        self.loadAttempts = loadAttempts; self.loadEvents = loadEvents; self.loadPathProgress = loadPathProgress; self.availableTopics = availableTopics
    }
    public func execute(now: Date, calendar: Calendar) throws -> WeeklyRecap {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let priorStart = calendar.date(byAdding: .day, value: -7, to: start)!
        let topics = try availableTopics()
        let path = try loadPathProgress()
        var ids = Set<UUID>()
        let attempts = try loadAttempts().filter { $0.submittedAt.timeIntervalSince1970.isFinite && $0.submittedAt <= now }.sorted {
            if $0.submittedAt != $1.submittedAt { return $0.submittedAt < $1.submittedAt }
            if $0.id != $1.id { return $0.id.uuidString < $1.id.uuidString }
            return $0.snapshot.fingerprint < $1.snapshot.fingerprint
        }.filter { ids.insert($0.id).inserted }
        var keys = Set<FirstAttemptKey>()
        let first = attempts.filter { keys.insert(.init(sessionID: $0.sessionID, fingerprint: $0.snapshot.fingerprint)).inserted }
        let current = first.filter { $0.submittedAt >= start }
        let prior = first.filter { $0.submittedAt >= priorStart && $0.submittedAt < start }
        func counts(_ values: [ExerciseAttempt]) -> LearningActivityCounts { .init(submitted: values.count, correct: values.filter { $0.outcome == .correct }.count) }
        let gradedCurrent = current.filter { $0.outcome != .selfRated && $0.snapshot.metadata?.assisted != true }
        let gradedPrior = prior.filter { $0.outcome != .selfRated && $0.snapshot.metadata?.assisted != true }
        var deltas: [ExerciseQuestionKind: WeeklyComparableDelta] = [:]
        for kind in Set(gradedCurrent.map { $0.snapshot.questionKind }) {
            let c = gradedCurrent.filter { $0.snapshot.questionKind == kind }
            let p = gradedPrior.filter { $0.snapshot.questionKind == kind }
            let shared = Set(c.map { $0.snapshot.fingerprint }).intersection(p.map { $0.snapshot.fingerprint })
            let cc = c.filter { shared.contains($0.snapshot.fingerprint) }; let pp = p.filter { shared.contains($0.snapshot.fingerprint) }
            if cc.count >= 10 && pp.count >= 10 { deltas[kind] = .init(current: counts(cc), prior: counts(pp)) }
        }
        var eventIDs = Set<UUID>(); var ratingKeys = Set<String>()
        let uniqueRatings = try loadEvents().filter { $0.submittedAt.timeIntervalSince1970.isFinite && $0.submittedAt <= now }.sorted {
            if $0.submittedAt != $1.submittedAt { return $0.submittedAt < $1.submittedAt }
            if $0.actionID != $1.actionID { return $0.actionID.uuidString < $1.actionID.uuidString }
            return $0.again && !$1.again
        }.filter { eventIDs.insert($0.actionID).inserted }
        let ratings = uniqueRatings.filter { ratingKeys.insert($0.sessionID.uuidString + ":" + $0.id.key).inserted }
        func selfCounts(_ from: Date, _ until: Date, inclusive: Bool) -> LearningActivityCounts {
            let events = ratings.filter { $0.submittedAt >= from && (inclusive ? $0.submittedAt <= until : $0.submittedAt < until) }
            let meaning = first.filter { $0.outcome == .selfRated && $0.submittedAt >= from && (inclusive ? $0.submittedAt <= until : $0.submittedAt < until) }
            return .init(submitted: events.count + meaning.count, correct: events.filter { !$0.again }.count + meaning.filter { $0.response == .selfRating(true) }.count)
        }
        let misses = current.filter { $0.outcome == .incorrect && $0.snapshot.metadata?.assisted != true }
        let grouped = Dictionary(grouping: misses.filter { $0.snapshot.metadata?.schemaVersion == 1 && !($0.snapshot.metadata?.topicID.isEmpty ?? true) }, by: { $0.snapshot.questionKind.rawValue + ":" + $0.snapshot.metadata!.topicID })
        let recurring = grouped.values.compactMap { values -> WeeklyTopic? in
            let sessions = Set(values.map { $0.sessionID }).count
            guard sessions >= 2, let latest = values.last, let topic = latest.snapshot.metadata?.topicID else { return nil }
            return .init(topicID: topic, kind: latest.snapshot.questionKind, sessions: sessions, latestMiss: latest.submittedAt, available: topics[topic] == latest.snapshot.questionKind)
        }.sorted { if $0.sessions != $1.sessions { return $0.sessions > $1.sessions }; if $0.latestMiss != $1.latestMiss { return $0.latestMiss > $1.latestMiss }; return $0.topicID < $1.topicID }
        let remaining = ExerciseHistoryQuery.latestMistakes(attempts).count
        let focus: WeeklyFocus
        if let topic = recurring.first(where: { $0.available }) { focus = .init(destination: .topic(kind: topic.kind, id: topic.topicID), reason: "This topic had a first-attempt miss in \(topic.sessions) separate sessions this week.") }
        else if remaining > 0 { focus = .init(destination: .mistakes, reason: "Revisit \(remaining) mistakes still awaiting a correct retry in retained history.") }
        else if path == nil || path?.currentStepID != nil { focus = .init(destination: .starterPath, reason: "Continue your saved starter path.") }
        else { focus = .init(destination: .practice, reason: "Choose a short practice session to build your local history.") }
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "MMM d, yyyy"
        let previousLastDay = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let days = Set((attempts.filter { $0.submittedAt >= start }.map(\.submittedAt) + uniqueRatings.filter { $0.submittedAt >= start }.map(\.submittedAt)).map { calendar.startOfDay(for: $0) }).count
        return .init(currentInterval: .init(start: start, end: now), priorInterval: .init(start: priorStart, end: start), priorRangeCaption: "\(formatter.string(from: priorStart)) – \(formatter.string(from: previousLastDay)) (\(calendar.timeZone.identifier))", practiceDays: days, rangeCaption: "\(formatter.string(from: start)) – \(formatter.string(from: now)) (\(calendar.timeZone.identifier))", firstAttemptCounts: Dictionary(grouping: gradedCurrent, by: { $0.snapshot.questionKind }).mapValues(counts), comparableDelta: deltas, selfRatedCurrent: selfCounts(start, now, inclusive: true), selfRatedPrior: selfCounts(priorStart, start, inclusive: false), recurringTopics: recurring, availableFocusIDs: Set(topics.keys), currentMistakes: remaining, currentActivityCount: attempts.filter { $0.submittedAt >= start }.count + uniqueRatings.filter { $0.submittedAt >= start }.count, focus: focus)
    }
}
