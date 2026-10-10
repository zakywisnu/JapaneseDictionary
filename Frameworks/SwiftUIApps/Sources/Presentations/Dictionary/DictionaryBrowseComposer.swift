import SwiftUI
import DataKit

extension AppComposer {
    func makeDictionaryBrowseView() -> some View {
        DictionaryBrowseView(viewModel: .init(loadSavedWords: { [self] in
            try dictionarySavedWords()
        }))
    }

    func makeDictionaryBrowseDetailView(catalogID: String, passageContext: PassageContext? = nil) -> some View {
        DictionaryBrowseDetailView(viewModel: .init(catalogID: catalogID, loadSavedWords: { [self] in
            try dictionarySavedWords()
        }, addWord: { [addSelectedWord] id in
            try addSelectedWord.execute(catalogID: id)
        }, passageContext: passageContext, savePassageWord: { [self] id, context in
            _ = try passageWordRepository().save(catalogID: id, passageID: context.id, title: context.title)
        }))
    }

    func passageWordRepository() -> StandardPassageWordRepository {
        StandardPassageWordRepository(store: store, prepare: { [self] in
            _ = try useCase.getWordsProgressUseCase.execute()
        })
    }

    private func dictionarySavedWords() throws -> [Kotoba] {
        // Browsing prepares first-use progress without adding an item or changing the sequential cursor.
        _ = try useCase.getWordsProgressUseCase.execute()
        return try useCase.getAllKotobaUseCase.execute().mapToKotobas()
    }
}
