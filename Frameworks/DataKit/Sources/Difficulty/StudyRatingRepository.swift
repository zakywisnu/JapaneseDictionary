import Foundation
import SwiftData

public protocol StudyRatingRepository {
    func records() throws -> [DifficultyRecord]
    func record(id: SavedStudyID, sessionID: UUID, actionID: UUID, again: Bool, now: Date, review: ReviewRecord?, activity: PracticeActivity?) throws
}

public final class StandardStudyRatingRepository: StudyRatingRepository {
    private let store: StudyStore
    private let saveContext: (ModelContext) throws -> Void
    public init(store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.store = store; saveContext = save
    }
    public func records() throws -> [DifficultyRecord] {
        try store.makeContext().fetch(FetchDescriptor<DifficultyRecordModel>()).map(\.value).sorted { $0.id.key < $1.id.key }
    }
    public func events() throws -> [ReviewRatingEvent] {
        try store.makeContext().fetch(FetchDescriptor<ReviewRatingEventModel>()).map { try $0.value() }.sorted { $0.submittedAt == $1.submittedAt ? $0.actionID.uuidString < $1.actionID.uuidString : $0.submittedAt < $1.submittedAt }
    }
    public func record(id: SavedStudyID, sessionID: UUID, actionID: UUID, again: Bool, now: Date, review: ReviewRecord? = nil, activity: PracticeActivity? = nil) throws {
        guard !id.id.isEmpty, now.timeIntervalSince1970.isFinite else { throw ReviewStoreError.invalidRecord }
        let context = store.makeContext()
        do {
            let event = ReviewRatingEvent(actionID: actionID, sessionID: sessionID, id: id, again: again, submittedAt: now)
            try ExerciseHistoryValidator.validateReviewRatingEvent(event)
            let events = try context.fetch(FetchDescriptor<ReviewRatingEventModel>())
            if let existing = try events.first(where: { $0.actionID == actionID })?.value() {
                guard existing == event else { throw ExerciseHistoryError.conflictingID }
                return
            }
            try requireSavedItem(id, context: context)
            let key = id.key
            let model = try context.fetch(FetchDescriptor<DifficultyRecordModel>(predicate: #Predicate { $0.key == key })).first
            if let review {
                try validateReviewRecord(review)
                guard review.id == id, review.lastSessionID == sessionID else { throw ReviewStoreError.invalidRecord }
            }
            if let activity {
                try BackupValidator.validateActivity(activity)
                guard !again, activity.studyID == id else { throw ReviewStoreError.invalidRecord }
            }
            let sameSession = model?.lastSessionID == sessionID
            let hadAgain = (sameSession && model?.sessionHadAgain == true) || again
            let oldCount = model?.missCount ?? 0
            guard !again || oldCount < Int.max else { throw ReviewStoreError.invalidRecord }
            let count = again ? oldCount + 1 : (hadAgain ? oldCount : 0)
            let value = DifficultyRecord(id: id, missCount: count, lastMissDate: again ? now : model?.lastMissDate, lastSessionID: sessionID, sessionHadAgain: hadAgain, lastActionID: actionID)
            if let model { model.apply(value) } else { context.insert(DifficultyRecordModel(value: value)) }
            if let review {
                if let model = try context.fetch(FetchDescriptor<ReviewRecordModel>(predicate: #Predicate { $0.key == key })).first { model.apply(review) }
                else { context.insert(ReviewRecordModel(record: review)) }
            }
            if let activity { try insertPracticeActivityIfNeeded(activity, context: context) }
            if events.count >= 10_000 {
                let values: [(ReviewRatingEventModel, ReviewRatingEvent)] = try events.map { model in (model, try model.value()) }
                let ordered = values.sorted { left, right in
                    if left.1.submittedAt != right.1.submittedAt { return left.1.submittedAt < right.1.submittedAt }
                    return left.1.actionID.uuidString < right.1.actionID.uuidString
                }
                // Keep complete sessions so retention cannot turn a later Got it into a first response.
                var removedSessions = Set<UUID>()
                var retainedCount = events.count
                for (_, oldEvent) in ordered where retainedCount >= 10_000 && oldEvent.sessionID != sessionID {
                    if removedSessions.insert(oldEvent.sessionID).inserted {
                        retainedCount -= values.filter { $0.1.sessionID == oldEvent.sessionID }.count
                    }
                }
                guard retainedCount < 10_000 else { throw ExerciseHistoryError.historyFull }
                for (model, oldEvent) in values where removedSessions.contains(oldEvent.sessionID) { context.delete(model) }
            }
            context.insert(try ReviewRatingEventModel(value: event))
            try saveContext(context); store.refreshContext()
        } catch { context.rollback(); throw error }
    }
}

func validateReviewRecord(_ record: ReviewRecord) throws {
    guard (0...4).contains(record.stage), record.sessionBaselineStage.map({ (0...4).contains($0) }) ?? true,
          !record.id.id.isEmpty, record.dueDate.timeIntervalSince1970.isFinite,
          record.lastReviewedAt.timeIntervalSince1970.isFinite else { throw ReviewStoreError.invalidRecord }
}
