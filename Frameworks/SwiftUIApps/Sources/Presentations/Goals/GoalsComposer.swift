import SwiftUI

extension AppComposer {
    func makeDailyGoalSummaryView() -> some View {
        DailyGoalSummaryView(viewModel: .init(getDailyGoal: getDailyGoal))
    }

    func makeDailyGoalSettingsView() -> some View {
        DailyGoalSettingsView(viewModel: .init(getDailyGoal: getDailyGoal, setDailyGoal: setDailyGoal))
    }
}
