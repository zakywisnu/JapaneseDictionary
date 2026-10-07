import Foundation

public struct ReviewScheduler {
    public init() {}

    public func nextStage(baseline: Int?, hadAgain: Bool) -> Int {
        hadAgain ? 0 : min((baseline ?? -1) + 1, 4)
    }

    public func dueDate(stage: Int, now: Date, calendar: Calendar) throws -> Date {
        let intervals = [1, 3, 7, 14, 30]
        guard intervals.indices.contains(stage), now >= .distantPast, now <= .distantFuture,
              let result = calendar.date(byAdding: .day, value: intervals[stage], to: calendar.startOfDay(for: now)),
              result <= .distantFuture else { throw ReviewSchedulingError.invalidDateOrStage }
        return result
    }
}

public enum ReviewSchedulingError: Error {
    case invalidDateOrStage
}
