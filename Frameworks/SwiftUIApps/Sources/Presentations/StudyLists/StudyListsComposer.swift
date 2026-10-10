import SwiftUI
import DataKit

extension AppComposer {
    func makeStudyListsView() -> some View {
        StudyListsView(viewModel: .init(useCases: studyLists))
    }
    func makeStudyListView(_ id: String) -> some View {
        StudyListDetailView(viewModel: .init(id: id, useCases: studyLists), savedDetail: { [self] id in
            switch id.kind {
            case .word:
                return .detail(.init(kotoba: try useCase.getKotobaDetailUseCase.execute(id: id.id).mapToKotoba(), kanji: nil))
            case .kanji:
                return .detail(.init(kotoba: nil, kanji: try useCase.getKanjiDetailUseCase.execute(id: id.id).asKanji))
            case .grammar, .sentence, .customCard:
                guard let material = try StandardStudyMaterialRepository(store: store).materials(kind: id.kind).first(where: { $0.id == id.id }) else { throw DataError.dataNotFound }
                return .material(material, saved: true)
            }
        })
    }
    func makeWordListMembershipView(wordID: String) -> some View {
        WordListMembershipView(viewModel: .init(wordID: wordID, useCases: studyLists), makeLists: { [self] in AnyView(StudyListsView(viewModel: .init(useCases: studyLists), opensDetails: false)) })
    }
    func makeItemListMembershipView(id: SavedStudyID) -> some View {
        WordListMembershipView(viewModel: .init(id: id, useCases: studyLists), makeLists: { [self] in AnyView(StudyListsView(viewModel: .init(useCases: studyLists), opensDetails: false)) })
    }
}
