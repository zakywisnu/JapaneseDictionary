import Foundation
import Observation
import DomainKit

@Observable
final class DailyGoalViewModel {
    struct State {
        var summary: DailyStudyGoalSummary?
        var isLoading = true
        var error: String?
        var selectedTarget: Int? = 10
        var saveError: String?
        var didSave = false
        var isSummaryVisible: Bool { summary?.target != nil }
    }
    enum Action { case load, selectTarget(Int?), save, cancel }
    var state = State()
    private let getDailyGoal: any GetDailyStudyGoalUseCase
    private let setDailyGoal: (any SetDailyStudyGoalUseCase)?
    private let now: () -> Date
    private var originalTarget: Int? = 10

    init(getDailyGoal: any GetDailyStudyGoalUseCase, setDailyGoal: (any SetDailyStudyGoalUseCase)? = nil, now: @escaping () -> Date = Date.init) {
        self.getDailyGoal = getDailyGoal
        self.setDailyGoal = setDailyGoal
        self.now = now
    }

    func send(_ action: Action) {
        switch action {
        case .load:
            state.isLoading = true
            state.error = nil
            do {
                let summary = try getDailyGoal.execute(now: now())
                state.summary = summary
                originalTarget = summary.target
                state.selectedTarget = summary.target
            } catch {
                state.summary = nil
                state.error = "Your daily practice activity couldn't be opened. Try again."
            }
            state.isLoading = false
        case .selectTarget(let target):
            state.selectedTarget = target
            state.didSave = false
            state.saveError = nil
        case .save:
            state.didSave = false
            guard let setDailyGoal else { return }
            do {
                try setDailyGoal.execute(target: state.selectedTarget)
                originalTarget = state.selectedTarget
                state.saveError = nil
                state.didSave = true
            } catch {
                state.saveError = "Your daily goal couldn't be saved. Try again or cancel to keep your previous goal."
            }
        case .cancel:
            state.selectedTarget = originalTarget
            state.saveError = nil
            state.didSave = false
        }
    }
}
