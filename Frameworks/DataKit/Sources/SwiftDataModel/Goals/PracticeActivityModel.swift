import Foundation
import SwiftData

public struct PracticeActivity: Codable, Equatable {
    public let key: String
    public let dayKey: String
    public let studyID: SavedStudyID
    public let completedAt: Date

    public init(key: String, dayKey: String, studyID: SavedStudyID, completedAt: Date) {
        self.key = key
        self.dayKey = dayKey
        self.studyID = studyID
        self.completedAt = completedAt
    }

    public init(id: SavedStudyID, completedAt: Date, calendar: Calendar = .autoupdatingCurrent) {
        let day = Self.dayKey(for: completedAt, calendar: calendar)
        self.init(key: Self.activityKey(dayKey: day, studyID: id), dayKey: day, studyID: id, completedAt: completedAt)
    }

    public static func dayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    public static func activityKey(dayKey: String, studyID: SavedStudyID) -> String {
        "\(dayKey):\(studyID.kind.rawValue):\(studyID.id.utf8.count):\(studyID.id)"
    }
}

@Model
public final class PracticeActivityModel {
    @Attribute(.unique) public var key: String
    public var dayKey: String
    public var kind: SavedStudyKind
    public var savedID: String
    public var completedAt: Date

    public init(activity: PracticeActivity) {
        key = activity.key
        dayKey = activity.dayKey
        kind = activity.studyID.kind
        savedID = activity.studyID.id
        completedAt = activity.completedAt
    }

    public var value: PracticeActivity {
        PracticeActivity(key: key, dayKey: dayKey, studyID: SavedStudyID(kind: kind, id: savedID), completedAt: completedAt)
    }
}
