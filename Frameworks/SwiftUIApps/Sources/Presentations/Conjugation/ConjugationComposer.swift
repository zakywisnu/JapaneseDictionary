import SwiftUI
import DataKit

@MainActor
extension AppComposer {
    func makeConjugationPracticeView(topicID: String? = nil, lemma: String? = nil) -> some View {
        let history = StandardExerciseHistoryRepository(store: store)
        return ConjugationSetupView(viewModel: .init(topicID: topicID, lemma: lemma, load: AppliedPracticeCatalogRepository.bundled, save: history.saveCheckpoint))
    }
}
