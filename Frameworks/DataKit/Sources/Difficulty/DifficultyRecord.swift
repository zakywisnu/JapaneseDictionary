import Foundation
import SwiftData

public struct DifficultyRecord: Codable, Equatable {
    public var id: SavedStudyID
    public var missCount: Int
    public var lastMissDate: Date?
    public var lastSessionID: UUID
    public var sessionHadAgain: Bool
    public var lastActionID: UUID
    public init(id: SavedStudyID, missCount: Int, lastMissDate: Date?, lastSessionID: UUID, sessionHadAgain: Bool, lastActionID: UUID) {
        self.id = id; self.missCount = missCount; self.lastMissDate = lastMissDate
        self.lastSessionID = lastSessionID; self.sessionHadAgain = sessionHadAgain; self.lastActionID = lastActionID
    }
}

@Model
public final class DifficultyRecordModel {
    @Attribute(.unique) public var key: String
    public var kind: SavedStudyKind
    public var savedID: String
    public var missCount: Int
    public var lastMissDate: Date?
    public var lastSessionID: UUID
    public var sessionHadAgain: Bool
    public var lastActionID: UUID
    public init(value: DifficultyRecord) {
        key = value.id.key; kind = value.id.kind; savedID = value.id.id
        missCount = value.missCount; lastMissDate = value.lastMissDate
        lastSessionID = value.lastSessionID; sessionHadAgain = value.sessionHadAgain; lastActionID = value.lastActionID
    }
    public var value: DifficultyRecord {
        DifficultyRecord(id: SavedStudyID(kind: kind, id: savedID), missCount: missCount, lastMissDate: lastMissDate, lastSessionID: lastSessionID, sessionHadAgain: sessionHadAgain, lastActionID: lastActionID)
    }
    func apply(_ value: DifficultyRecord) {
        missCount = value.missCount; lastMissDate = value.lastMissDate
        lastSessionID = value.lastSessionID; sessionHadAgain = value.sessionHadAgain; lastActionID = value.lastActionID
    }
}
