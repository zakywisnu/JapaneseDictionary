import SwiftUI

extension AppComposer {
    func makeStudyListsView() -> some View {
        StudyListsView(viewModel: .init(useCases: studyLists))
    }
    func makeStudyListView(_ id: String) -> some View {
        StudyListDetailView(viewModel: .init(id: id, useCases: studyLists), savedDetail: { [self] wordID in
            let word = try useCase.getKotobaDetailUseCase.execute(id: wordID).mapToKotoba()
            return .init(kotoba: word, kanji: nil)
        })
    }
    func makeWordListMembershipView(wordID: String) -> some View {
        WordListMembershipView(viewModel: .init(wordID: wordID, useCases: studyLists), makeLists: { [self] in AnyView(StudyListsView(viewModel: .init(useCases: studyLists), opensDetails: false)) })
    }
}
