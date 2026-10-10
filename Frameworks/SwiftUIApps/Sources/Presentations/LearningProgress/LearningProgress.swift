import Foundation
import DataKit
import DomainKit
import Observation

@Observable final class LearningProgressViewModel {
    struct State { var days = 7; var summary: LearningProgressSummary?; var dueCount = 0; var error: String?; var loading = true }
    enum Action { case load, range(Int) }
    private(set) var state = State()
    private let load: () throws -> ([ExerciseAttempt], [ReviewRatingEvent])
    private let loadAdditional: () throws -> ([PracticeActivity], LearningPathProgress?)
    private let loadDue: (Date) throws -> [DueReview]
    private let now: () -> Date
    private let calendar: Calendar
    init(load: @escaping () throws -> ([ExerciseAttempt], [ReviewRatingEvent]), now: @escaping () -> Date = Date.init, calendar: Calendar = .current, loadAdditional: @escaping () throws -> ([PracticeActivity], LearningPathProgress?) = { ([], nil) }, loadDue: @escaping (Date) throws -> [DueReview] = { _ in [] }) {
        self.load = load; self.now = now; self.calendar = calendar; self.loadAdditional = loadAdditional; self.loadDue = loadDue
    }
    func send(_ action: Action) {
        if case .range(let days) = action { guard [1, 7, 30].contains(days) else { return }; state.days = days }
        state.loading = true; state.error = nil
        do { let instant = now(); state.dueCount = Set(try loadDue(instant).map { $0.item.id }).count; let values = try load(); let additional = try loadAdditional(); state.summary = .calculate(attempts: values.0, events: values.1, days: state.days, now: instant, calendar: calendar, activities: additional.0, pathProgress: additional.1, pathSteps: StarterPathCatalog.steps) }
        catch { state.summary = nil; state.error = "Your saved collection, exercise history or review dates couldn't load. Try again." }
        state.loading = false
    }
}
