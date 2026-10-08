import Foundation
import SwiftData

public struct DailyGoalSettings: Codable, Equatable {
    public let target: Int?
    public init(target: Int? = 10) { self.target = target }
}

@Model
public final class DailyGoalSettingsModel {
    public static let singletonID = "daily-goal"
    @Attribute(.unique) public var id: String
    public var target: Int?

    public init(settings: DailyGoalSettings = DailyGoalSettings()) {
        id = Self.singletonID
        target = settings.target
    }

    public var value: DailyGoalSettings { DailyGoalSettings(target: target) }
}
