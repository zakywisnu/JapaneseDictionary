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
    public func record(id: SavedStudyID, sessionID: UUID, actionID: UUID, again: Bool, now: Date, review: ReviewRecord? = nil, activity: PracticeActivity? = nil) throws {
        guard !id.id.isEmpty, now.timeIntervalSince1970.isFinite else { throw ReviewStoreError.invalidRecord }
        let context = store.makeContext()
        do {
            try requireSavedItem(id, context: context)
            let key = id.key
            let model = try context.fetch(FetchDescriptor<DifficultyRecordModel>(predicate: #Predicate { $0.key == key })).first
            if model?.lastActionID == actionID { return }
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
            try saveContext(context); store.refreshContext()
        } catch { context.rollback(); throw error }
    }
}

func validateReviewRecord(_ record: ReviewRecord) throws {
    guard (0...4).contains(record.stage), record.sessionBaselineStage.map({ (0...4).contains($0) }) ?? true,
          !record.id.id.isEmpty, record.dueDate.timeIntervalSince1970.isFinite,
          record.lastReviewedAt.timeIntervalSince1970.isFinite else { throw ReviewStoreError.invalidRecord }
}
