import Foundation
import DataKit

public struct DailyStudyGoalSummary: Equatable {
    public let target: Int?
    public let completedCount: Int
    public var isReached: Bool { target.map { completedCount >= $0 } ?? false }
    public init(target: Int?, completedCount: Int) {
        self.target = target
        self.completedCount = completedCount
    }
}

public protocol GetDailyStudyGoalUseCase {
    func execute(now: Date) throws -> DailyStudyGoalSummary
}

public struct DefaultGetDailyStudyGoalUseCase: GetDailyStudyGoalUseCase {
    private let repository: DailyGoalRepository
    private let calendar: Calendar
    public init(repository: DailyGoalRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }
    public func execute(now: Date) throws -> DailyStudyGoalSummary {
        let day = PracticeActivity.dayKey(for: now, calendar: calendar)
        return DailyStudyGoalSummary(target: try repository.target(), completedCount: try repository.activities(dayKey: day).count)
    }
}

public protocol SetDailyStudyGoalUseCase {
    func execute(target: Int?) throws
}

public struct DefaultSetDailyStudyGoalUseCase: SetDailyStudyGoalUseCase {
    private let repository: DailyGoalRepository
    public init(repository: DailyGoalRepository) { self.repository = repository }
    public func execute(target: Int?) throws { try repository.setTarget(target) }
}

public protocol PracticeCompletionUseCase {
    func execute(id: SavedStudyID, now: Date) throws
}

public struct DefaultPracticeCompletionUseCase: PracticeCompletionUseCase {
    private let repository: DailyGoalRepository
    private let calendar: Calendar
    public init(repository: DailyGoalRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }
    public func execute(id: SavedStudyID, now: Date) throws {
        try repository.record(PracticeActivity(id: id, completedAt: now, calendar: calendar))
    }
}
