import SwiftUI
import DataKit
import Observation
import DomainKit

@Observable final class LearningPathViewModel {
    struct State { var loading = true; var progress: LearningPathProgress?; var statuses: [LearningPathStepStatus] = []; var readyToComplete: Set<String> = []; var error: String? }
    enum Action { case load, complete(String), skip(String), revisit(String) }
    private(set) var state = State()
    private let loadAttempts: () throws -> [ExerciseAttempt]
    private let repository: StandardLearningPathRepository
    init(repository: StandardLearningPathRepository, loadAttempts: @escaping () throws -> [ExerciseAttempt] = { [] }) { self.repository = repository; self.loadAttempts = loadAttempts }
    func send(_ action: Action) {
        state.error = nil
        do {
            switch action {
            case .load: state.loading = true
            case .complete(let id):
                guard let step = StarterPathCatalog.steps.first(where: { $0.id == id }) else { return }
                _ = try repository.complete(step: step, steps: StarterPathCatalog.steps, pathID: StarterPathCatalog.id, now: Date())
            case .skip(let id): _ = try repository.skip(stepID: id, steps: StarterPathCatalog.steps, pathID: StarterPathCatalog.id, now: Date())
            case .revisit(let id): _ = try repository.revisit(stepID: id, steps: StarterPathCatalog.steps, pathID: StarterPathCatalog.id, now: Date())
            }
            state.progress = try repository.progress(pathID: StarterPathCatalog.id)
            let attempts = try loadAttempts()
            state.readyToComplete = Set(StarterPathCatalog.steps.filter { LearningStepCompletionPolicy().isComplete(step: $0, attempts: attempts) && !(state.progress?.isComplete($0) ?? false) }.map(\.id))
            state.statuses = LearningProgressSummary.calculate(attempts: attempts, events: [], days: 1, now: Date(), calendar: .current, pathProgress: state.progress, pathSteps: StarterPathCatalog.steps).pathStepStatuses
            if state.progress?.currentStepID == nil, let first = state.statuses.firstIndex(where: { ![.completed, .skipped].contains($0.status) }) { state.statuses[first].status = .current }
        } catch LearningPathError.incompleteActivity { state.error = "Answer each question in this step before marking it complete. Correct answers are not required." }
        catch { state.error = "Your path progress couldn't be saved or opened. Try again." }
        state.loading = false
    }
}

struct LearningPathView: View {
    @State var viewModel: LearningPathViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        List {
            Section { Text("Eight steps in kana, grammar and reading. Complete a step by attempting its questions; completion does not measure mastery.").font(.subheadline).foregroundStyle(Forest.inkMuted) }.listRowBackground(Forest.surface)
            if viewModel.state.loading { ProgressView("Loading your path") }
            if let error = viewModel.state.error { StateMessage(title: "Path unavailable", message: error, actionTitle: "Try again", action: { viewModel.send(.load) }).listRowBackground(Forest.surface) }
            if !viewModel.state.loading, viewModel.state.error == nil {
                Section {
                    ForEach(StarterPathCatalog.steps) { step in
                        ForestNavigationRow(title: step.title, subtitle: statusTitle(step.id)) {
                            viewModel.send(.revisit(step.id))
                            if viewModel.state.error == nil { router.push(.learningStep(step.id), hideNavBar: false) }
                        }.listRowInsets(EdgeInsets())
                    }
                }.listRowBackground(Forest.surface)
            }
        }.forestTabList().navigationTitle("Starter path").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar).onAppear { viewModel.send(.load) }
    }

    private func statusTitle(_ id: String) -> String {
        if viewModel.state.progress?.currentStepID == id { return viewModel.state.progress?.completedRevisions.contains(where: { $0.stepID == id }) == true ? "Current step · previously completed" : "Current step" }
        switch viewModel.state.statuses.first(where: { $0.stepID == id })?.status {
        case .current: return "Current step"
        case .attempted: return "Attempted · finish the remaining questions"
        case .completed: return "Completed this revision"
        case .skipped: return "Skipped"
        default: return "Not started"
        }
    }

}

@MainActor extension AppComposer {
    func makeLearningPathView() -> some View { LearningPathView(viewModel: .init(repository: StandardLearningPathRepository(store: store), loadAttempts: StandardExerciseHistoryRepository(store: store).attempts)) }
    func makeLearningStepView(id: String) -> some View {
        LearningStepRouteView(stepID: id, viewModel: .init(repository: StandardLearningPathRepository(store: store), loadAttempts: StandardExerciseHistoryRepository(store: store).attempts))
    }
    @ViewBuilder func makeLearningStepContentView(id: String) -> some View {
        if let step = StarterPathCatalog.steps.first(where: { $0.id == id }) {
            if let group = StarterPathCatalog.kanaGroups.first(where: { $0.0 == id }) {
                makePathKanaPracticeView(script: group.1, group: group.2, activityKey: step.activityKey)
            } else {
                VStack(spacing: 0) {
                    if id == "morning" || id == "more-reading" {
                        Menu("Read passage before questions") {
                            ForEach(ReadingCatalog.passages.filter { id == "morning" ? $0.id == "morning" : $0.id != "morning" }) { passage in
                                NavigationLink(passage.title, value: AppRoutes.readingPassage(passage.id))
                            }
                        }.foregroundStyle(Forest.ink).frame(minHeight: 44)
                    }
                    makeExerciseSessionView(exercises: StarterPathCatalog.exercises(for: id), activityKey: step.activityKey, title: step.title)
                }
            }
        } else { StateMessage(title: "Step unavailable", message: "Go back and choose a step from the current starter path.") }
    }
}

private struct LearningStepRouteView: View {
    let stepID: String
    @State var viewModel: LearningPathViewModel
    @EnvironmentObject private var router: AppRouter
    var body: some View {
        AppComposer.shared.makeLearningStepContentView(id: stepID)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Step options", systemImage: "ellipsis") {
                        if viewModel.state.readyToComplete.contains(stepID) {
                            Button("Complete from past practice") { finish(.complete(stepID)) }
                        }
                        Button("Skip for now") { finish(.skip(stepID)) }
                    }.tint(Forest.ink)
                }
            }
            .onAppear { viewModel.send(.load) }
            .alert("Couldn't update this step", isPresented: Binding(get: { viewModel.state.error != nil }, set: { if !$0 { viewModel.send(.load) } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(viewModel.state.error ?? "") }
    }
    private func finish(_ action: LearningPathViewModel.Action) {
        viewModel.send(action)
        if viewModel.state.error == nil { router.pop() }
    }
}
