import Foundation
import SwiftData

public enum SavedStudyKind: String, Codable, Hashable, CaseIterable {
    case word, kanji
}

public struct SavedStudyID: Codable, Hashable {
    public let kind: SavedStudyKind
    public let id: String
    public var key: String { kind.rawValue + ":" + id }
    public init(kind: SavedStudyKind, id: String) {
        self.kind = kind
        self.id = id
    }
}

public struct ReviewRecord: Codable, Equatable {
    public let id: SavedStudyID
    public let stage: Int
    public let dueDate: Date
    public let lastReviewedAt: Date
    public let lastSessionID: UUID
    public let sessionBaselineStage: Int?
    public let sessionHadAgain: Bool

    public init(id: SavedStudyID, stage: Int, dueDate: Date, lastReviewedAt: Date, lastSessionID: UUID, sessionBaselineStage: Int?, sessionHadAgain: Bool) {
        self.id = id
        self.stage = stage
        self.dueDate = dueDate
        self.lastReviewedAt = lastReviewedAt
        self.lastSessionID = lastSessionID
        self.sessionBaselineStage = sessionBaselineStage
        self.sessionHadAgain = sessionHadAgain
    }
}

@Model
public final class ReviewRecordModel {
    @Attribute(.unique) public var key: String
    public var kind: SavedStudyKind
    public var savedID: String
    public var stage: Int
    public var dueDate: Date
    public var lastReviewedAt: Date
    public var lastSessionID: UUID
    public var sessionBaselineStage: Int?
    public var sessionHadAgain: Bool

    public init(record: ReviewRecord) {
        key = record.id.key
        kind = record.id.kind
        savedID = record.id.id
        stage = record.stage
        dueDate = record.dueDate
        lastReviewedAt = record.lastReviewedAt
        lastSessionID = record.lastSessionID
        sessionBaselineStage = record.sessionBaselineStage
        sessionHadAgain = record.sessionHadAgain
    }

    public var value: ReviewRecord {
        ReviewRecord(id: SavedStudyID(kind: kind, id: savedID), stage: stage, dueDate: dueDate, lastReviewedAt: lastReviewedAt, lastSessionID: lastSessionID, sessionBaselineStage: sessionBaselineStage, sessionHadAgain: sessionHadAgain)
    }

    func apply(_ record: ReviewRecord) {
        stage = record.stage
        dueDate = record.dueDate
        lastReviewedAt = record.lastReviewedAt
        lastSessionID = record.lastSessionID
        sessionBaselineStage = record.sessionBaselineStage
        sessionHadAgain = record.sessionHadAgain
    }
}
