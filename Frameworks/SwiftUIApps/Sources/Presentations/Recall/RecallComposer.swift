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
        ExerciseResumeView(activityKey: activityKey, load: { [self] in
            guard let checkpoint = try StandardExerciseHistoryRepository(store: store).checkpoint(activityKey: activityKey) else { return nil }
            let questions = try ExerciseResumePolicy.currentQuestions(checkpoint)
            return RecallSessionViewModel(questions: questions, activityKey: activityKey, isListening: activityKey.hasPrefix("listening:"), persistence: exercisePersistence(activityKey: activityKey))
        })
    }
}

private struct ExerciseResumeView: View {
    let activityKey: String
    let load: () throws -> RecallSessionViewModel?
    @State private var model: RecallSessionViewModel?
    @State private var isLoading = true
    @State private var error: String?
    var body: some View {
        Group {
            if let model { RecallSessionView(viewModel: model, title: "Continue practice") }
            else {
                ScrollView {
                    if isLoading { ProgressView("Opening unfinished practice") }
                    else if let error { StateMessage(title: "Couldn't open practice", message: error, actionTitle: "Try again", action: reload) }
                    else { StateMessage(title: "This practice has finished", message: "Return to Learning practice to start another session.") }
                }.background(Forest.canvas).navigationTitle("Continue practice")
            }
        }.onAppear { if model == nil { reload() } }
    }
    private func reload() {
        isLoading = true; error = nil
        do { model = try load() }
        catch { self.error = "Your unfinished practice couldn't be opened. Try again." }
        isLoading = false
    }
}
