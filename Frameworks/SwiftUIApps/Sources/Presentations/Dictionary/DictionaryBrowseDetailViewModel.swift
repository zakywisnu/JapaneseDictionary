import Foundation
import Observation
import DataKit

@Observable
final class DictionaryBrowseDetailViewModel {
    private(set) var state = State()
    private let catalogID: String
    private let loadCatalog: () throws -> VocabularyCatalogRepository
    private let loadSavedWords: () throws -> [Kotoba]
    let passageContext: PassageContext?
    private let savePassageWord: ((String, PassageContext) throws -> Void)?
    private let addWord: (String) throws -> Void

    init(catalogID: String, loadCatalog: @escaping () throws -> VocabularyCatalogRepository = { try .bundled() },
         loadSavedWords: @escaping () throws -> [Kotoba], addWord: @escaping (String) throws -> Void, passageContext: PassageContext? = nil, savePassageWord: ((String, PassageContext) throws -> Void)? = nil) {
        self.passageContext = passageContext
        self.savePassageWord = savePassageWord
        self.catalogID = catalogID
        self.loadCatalog = loadCatalog
        self.loadSavedWords = loadSavedWords
        self.addWord = addWord
    }

    var canAdd: Bool {
        state.loadState == .loaded && state.word != nil && state.savedWord == nil && !state.isAdding
    }

    var canSaveToPassage: Bool {
        state.loadState == .loaded && state.word != nil && passageContext != nil && savePassageWord != nil && !state.isAdding && !state.didSaveToPassage
    }

    func send(_ action: Action) {
        switch action {
        case .load:
            reload()
        case .add:
            guard canAdd else { return }
            state.isAdding = true
            state.errorMessage = nil
            defer { state.isAdding = false }
            do {
                try addWord(catalogID)
                state.didAdd = true
                // A committed addition may need a separate membership retry; never offer another unsafe add.
                reload()
            } catch {
                state.errorMessage = "This word couldn't be added to your collection. Try again."
            }
        case .saveToPassage:
            guard canSaveToPassage, let passageContext, let savePassageWord else { return }
            state.isAdding = true; state.errorMessage = nil
            defer { state.isAdding = false }
            do {
                try savePassageWord(catalogID, passageContext)
                state.didSaveToPassage = true; state.didAdd = true
                reload()
            } catch {
                state.errorMessage = "This word couldn't be saved to \(passageContext.title). Try Save to passage list again."
            }
        case .dismissError:
            state.errorMessage = nil
        }
    }

    private func reload() {
        state.loadState = .loading
        state.savedWord = nil
        do {
            state.word = try loadCatalog().word(id: catalogID)
        } catch {
            state.word = nil
            state.loadState = .failed
            state.loadError = "The bundled dictionary couldn't be read. Try again."
            return
        }
        do {
            state.savedWord = try loadSavedWords().filter { $0.catalogID == catalogID }.min { $0.id < $1.id }
            state.loadError = nil
            state.loadState = .loaded
        } catch {
            state.loadState = .failed
            state.loadError = state.didAdd
                ? "This word was added, but your saved collection couldn't be reloaded. Try again to open the saved word."
                : "Your saved collection couldn't be read. Try again before adding this word."
        }
    }

    struct State {
        var word: DictionaryWord?
        var savedWord: Kotoba?
        var loadState: TodayLoadState = .loading
        var loadError: String?
        var errorMessage: String?
        var isAdding = false
        var didAdd = false
        var didSaveToPassage = false
    }

    enum Action { case load, add, saveToPassage, dismissError }
}
