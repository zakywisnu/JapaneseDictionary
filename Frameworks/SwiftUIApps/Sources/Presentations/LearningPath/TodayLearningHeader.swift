import SwiftUI
import DataKit
import DomainKit
import Observation

private struct TodayHeaderKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var showsTodayHeader: Bool { get { self[TodayHeaderKey.self] } set { self[TodayHeaderKey.self] = newValue } }
}

@Observable final class ContinueLearningViewModel {
    struct State { var loading = true; var destination: LearningDestination?; var error: String? }
    enum Action { case load }
    private(set) var state = State()
    private let useCase: ContinueLearningUseCase
    init(useCase: ContinueLearningUseCase) { self.useCase = useCase }
    func send(_ action: Action) {
        state.loading = true; state.error = nil
        do { state.destination = try useCase.execute() }
        catch { state.destination = nil; state.error = "Your unfinished practice or starter path couldn't load. Try again." }
        state.loading = false
    }
}

struct TodayLearningHeader: View {
    @EnvironmentObject private var router: AppRouter
    @AppStorage("todayStudyKind") private var kind: StudyKind = .words
    @State private var viewModel: ContinueLearningViewModel
    init() {
        let composer = AppComposer.shared
        let history = StandardExerciseHistoryRepository(store: composer.store)
        let path = StandardLearningPathRepository(store: composer.store)
        _viewModel = State(initialValue: .init(useCase: .init(loadCheckpoints: history.checkpoints, loadProgress: { try path.progress(pathID: StarterPathCatalog.id) }, steps: StarterPathCatalog.steps, validCheckpoint: ExerciseResumePolicy.isCurrent)))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Forest.Space.l) {
            ScreenHeader(title: "Today", caption: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            if viewModel.state.loading { ProgressView("Finding your next practice") }
            else if let error = viewModel.state.error { StateMessage(title: "Couldn't continue learning", message: error, actionTitle: "Try again", action: { viewModel.send(.load) }) }
            else if let destination = viewModel.state.destination {
                VStack(alignment: .leading, spacing: Forest.Space.m) {
                    Text(destination.sessionID == nil ? "Your next starter step" : "Pick up your unfinished practice").font(.headline)
                    Button("Continue learning") {
                        if let id = destination.stepID { router.push(.learningStep(id), hideNavBar: false) }
                        else { router.push(.exerciseResume(destination.activityKey), hideNavBar: false) }
                    }.buttonStyle(PrimaryButtonStyle())
                }.padding(Forest.Space.l).background(Forest.surface, in: .rect(cornerRadius: Forest.Radius.card))
            } else { Text("Starter path completed. Revisit a step or choose more practice.").font(.subheadline).foregroundStyle(Forest.inkMuted) }
            AppComposer.shared.makeDailyGoalSummaryView()
            AppComposer.shared.makeDailyStudyPlanSummaryView()
            StudyKindPicker(selection: $kind)
        }.onAppear { viewModel.send(.load) }
    }
}
