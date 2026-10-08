import Foundation
import DataKit

public protocol RecordReviewUseCase {
    func execute(id: SavedStudyID, sessionID: UUID, rating: RecallRating, now: Date) throws
}

public struct DefaultRecordReviewUseCase: RecordReviewUseCase {
    private let repository: ReviewRepository
    private let scheduler: ReviewScheduler
    private let calendar: Calendar

    public init(repository: ReviewRepository, scheduler: ReviewScheduler = ReviewScheduler(), calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.scheduler = scheduler
        self.calendar = calendar
    }

    public func execute(id: SavedStudyID, sessionID: UUID, rating: RecallRating, now: Date) throws {
        let previous = try repository.records().first { $0.id == id }
        let sameSession = previous?.lastSessionID == sessionID
        let baseline = sameSession ? previous?.sessionBaselineStage : previous?.stage
        let hadAgain = (sameSession && previous?.sessionHadAgain == true) || rating == .again
        let stage = scheduler.nextStage(baseline: baseline, hadAgain: hadAgain)
        // Retries preserve the first saved timestamp and due date for this session.
        let reviewedAt = sameSession ? previous!.lastReviewedAt : now
        let dueDate = try scheduler.dueDate(stage: stage, now: reviewedAt, calendar: calendar)
        let activity = rating == .gotIt ? PracticeActivity(id: id, completedAt: now, calendar: calendar) : nil
        try repository.save(ReviewRecord(id: id, stage: stage, dueDate: dueDate, lastReviewedAt: reviewedAt, lastSessionID: sessionID, sessionBaselineStage: baseline, sessionHadAgain: hadAgain), activity: activity)
    }
}
