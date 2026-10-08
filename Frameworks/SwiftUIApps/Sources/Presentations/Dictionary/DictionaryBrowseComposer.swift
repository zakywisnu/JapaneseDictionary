import SwiftUI

extension AppComposer {
    func makeDictionaryBrowseView() -> some View {
        DictionaryBrowseView(viewModel: .init(loadSavedWords: { [self] in
            try dictionarySavedWords()
        }))
    }

    func makeDictionaryBrowseDetailView(catalogID: String) -> some View {
        DictionaryBrowseDetailView(viewModel: .init(catalogID: catalogID, loadSavedWords: { [self] in
            try dictionarySavedWords()
        }, addWord: { [addSelectedWord] id in
            try addSelectedWord.execute(catalogID: id)
        }))
    }

    private func dictionarySavedWords() throws -> [Kotoba] {
        // Browsing prepares first-use progress without adding an item or changing the sequential cursor.
        _ = try useCase.getWordsProgressUseCase.execute()
        return try useCase.getAllKotobaUseCase.execute().mapToKotobas()
    }
}
