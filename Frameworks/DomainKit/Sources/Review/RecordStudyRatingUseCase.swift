import Foundation
import DataKit

public protocol RecordStudyRatingUseCase {
    func execute(id: SavedStudyID, sessionID: UUID, actionID: UUID, rating: RecallRating, now: Date, isDue: Bool) throws
}

public struct DefaultRecordStudyRatingUseCase: RecordStudyRatingUseCase {
    private let reviewRepository: ReviewRepository
    private let ratingRepository: StudyRatingRepository
    private let calendar: Calendar
    public init(reviewRepository: ReviewRepository, ratingRepository: StudyRatingRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.reviewRepository = reviewRepository; self.ratingRepository = ratingRepository; self.calendar = calendar
    }
    public func execute(id: SavedStudyID, sessionID: UUID, actionID: UUID, rating: RecallRating, now: Date, isDue: Bool) throws {
        var review: ReviewRecord?
        if isDue {
            let previous = try reviewRepository.records().first { $0.id == id }
            let sameSession = previous?.lastSessionID == sessionID
            let baseline = sameSession ? previous?.sessionBaselineStage : previous?.stage
            let hadAgain = (sameSession && previous?.sessionHadAgain == true) || rating == .again
            let scheduler = ReviewScheduler()
            let stage = scheduler.nextStage(baseline: baseline, hadAgain: hadAgain)
            let reviewedAt = sameSession ? previous!.lastReviewedAt : now
            review = ReviewRecord(id: id, stage: stage, dueDate: try scheduler.dueDate(stage: stage, now: reviewedAt, calendar: calendar), lastReviewedAt: reviewedAt, lastSessionID: sessionID, sessionBaselineStage: baseline, sessionHadAgain: hadAgain)
        }
        let activity = rating == .gotIt ? PracticeActivity(id: id, completedAt: now, calendar: calendar) : nil
        try ratingRepository.record(id: id, sessionID: sessionID, actionID: actionID, again: rating == .again, now: now, review: review, activity: activity)
    }
}
