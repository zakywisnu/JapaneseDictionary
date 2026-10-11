import SwiftUI
import DataKit
import DomainKit

extension AppComposer {
    func makeWeeklyRecapView(availableTopics: @escaping () throws -> [String: ExerciseQuestionKind] = { [:] }, onFocus: @escaping (WeeklyFocusDestination) -> Void = { _ in }) -> some View {
        WeeklyRecapView(viewModel: weeklyRecapViewModel(availableTopics: availableTopics, onFocus: onFocus))
    }
    func makeWeeklyRecapSummaryView(openRecap: @escaping () -> Void) -> some View {
        WeeklyRecapSummaryView(viewModel: weeklyRecapViewModel(), openRecap: openRecap)
    }
    private func weeklyRecapViewModel(availableTopics: @escaping () throws -> [String: ExerciseQuestionKind] = { [:] }, onFocus: @escaping (WeeklyFocusDestination) -> Void = { _ in }) -> WeeklyRecapViewModel {
        let useCase = WeeklyRecapUseCase(loadAttempts: StandardExerciseHistoryRepository(store: store).attempts, loadEvents: StandardStudyRatingRepository(store: store).events, loadPathProgress: { [self] in try StandardLearningPathRepository(store: store).progress(pathID: StarterPathCatalog.id) }, availableTopics: availableTopics)
        return .init(load: { try useCase.execute(now: Date(), calendar: .current) }, open: onFocus)
    }
}
