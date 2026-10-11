import SwiftUI
import DataKit

@MainActor
extension AppComposer {
    func makeTypedPracticeView() -> some View { makeRecallSelectionView(listening: false) }
    func makeListeningPracticeView() -> some View { makeRecallSelectionView(listening: true) }
    private func makeRecallSelectionView(listening: Bool) -> some View {
        let reviews = StandardReviewRepository(store: store)
        let history = StandardExerciseHistoryRepository(store: store)
        return RecallSelectionView(viewModel: .init(isListening: listening, loadItems: {
            try SavedStudyKind.allCases.flatMap { try reviews.savedItems(kind: $0) }
        }, loadLists: studyLists.lists, loadMembers: { [studyLists] id in try studyLists.items(listID: id) }, save: history.saveCheckpoint))
    }
    func makePathKanaPracticeView(script: KanaScript, group: KanaGroup, activityKey: String) -> some View {
        let questions = KanaCatalog.entries.filter { $0.script == script && $0.group == group }.compactMap { RecallSelectionViewModel.kanaQuestion($0, mode: .romanization, listening: false) }
        return RecallSessionView(viewModel: .init(questions: questions, activityKey: activityKey, persistence: exercisePersistence(activityKey: activityKey)), title: "Kana romanization")
    }
    func makeRecallSessionView(snapshots: [ExerciseSnapshot], activityKey: String, title: String, listening: Bool = false) -> some View {
        RecallSessionView(viewModel: .init(questions: snapshots.map(ExerciseResumePolicy.historicalQuestion), activityKey: activityKey, isListening: listening, persistence: exercisePersistence(activityKey: activityKey)), title: title)
    }
    func makeExerciseResumeView(activityKey: String) -> some View {
        AppliedExerciseResumeView(activityKey: activityKey)
    }
}

private struct AppliedExerciseResumeView: View {
    let activityKey: String
    @State private var questions: [ExerciseSnapshot] = []
    @State private var loading = true
    @State private var error: String?
    var body: some View {
        Group {
            if !questions.isEmpty {
                let composer = AppComposer.shared
                if questions.first?.questionKind == .sentenceOrder {
                    composer.makeSentenceBuildingSessionView(snapshots: questions, activityKey: activityKey, title: "Sentence building")
                } else if questions.first?.questionKind == .listeningComprehension {
                    composer.makeListeningComprehensionSessionView(snapshots: questions, activityKey: activityKey, title: "Listening comprehension")
                } else {
                    composer.makeRecallSessionView(snapshots: questions, activityKey: activityKey, title: "Continue practice", listening: ExerciseResumePolicy.requiresListening(activityKey: activityKey, snapshots: questions))
                }
            } else {
                ScrollView {
                    if loading { ProgressView("Opening unfinished practice") }
                    else if let error { StateMessage(title: "Couldn't open practice", message: error, actionTitle: "Try again", action: reload) }
                    else { StateMessage(title: "This practice has finished or changed", message: "Return to Practice to start another session. Your submitted answers remain in History.") }
                }.background(Forest.canvas).navigationTitle("Continue practice").toolbar(.visible, for: .navigationBar)
            }
        }.onAppear { if questions.isEmpty { reload() } }
    }
    private func reload() {
        loading = true; error = nil
        do {
            let composer = AppComposer.shared
            if let checkpoint = try StandardExerciseHistoryRepository(store: composer.store).checkpoint(activityKey: activityKey) {
                questions = try ExerciseResumePolicy.currentQuestions(checkpoint).map(\.snapshot)
            }
        } catch { self.error = "Your unfinished practice couldn't open. Try again." }
        loading = false
    }
}
