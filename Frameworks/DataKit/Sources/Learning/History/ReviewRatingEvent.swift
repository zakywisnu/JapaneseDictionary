import Foundation
import SwiftData

public struct ReviewRatingEvent: Codable, Equatable {
    public var actionID: UUID
    public var sessionID: UUID
    public var id: SavedStudyID
    public var again: Bool
    public var submittedAt: Date
    public var contextID: String?
    public init(actionID: UUID, sessionID: UUID, id: SavedStudyID, again: Bool, submittedAt: Date, contextID: String? = nil) {
        self.actionID = actionID; self.sessionID = sessionID; self.id = id; self.again = again; self.submittedAt = submittedAt; self.contextID = contextID
    }
}
@Model public final class ReviewRatingEventModel {
    @Attribute(.unique) public var actionID: UUID
    public var payload: Data
    public init(value: ReviewRatingEvent) throws { actionID = value.actionID; payload = try JSONEncoder().encode(value) }
    public func value() throws -> ReviewRatingEvent {
        let value = try JSONDecoder().decode(ReviewRatingEvent.self, from: payload)
        guard value.actionID == actionID else { throw ExerciseHistoryError.invalidRecord }
        try ExerciseHistoryValidator.validateReviewRatingEvent(value)
        return value
    }
}
