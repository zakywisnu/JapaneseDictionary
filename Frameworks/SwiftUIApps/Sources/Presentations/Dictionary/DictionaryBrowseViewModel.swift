import DataKit
import Observation

@Observable
final class DictionaryBrowseViewModel {
    var state = State()

    private let loadCatalog: () throws -> VocabularyCatalogRepository
    private let loadSavedWords: () throws -> [Kotoba]
    private var index: DictionarySearchIndex?

    init(
        loadCatalog: @escaping () throws -> VocabularyCatalogRepository = { try .bundled() },
        loadSavedWords: @escaping () throws -> [Kotoba]
    ) {
        self.loadCatalog = loadCatalog
        self.loadSavedWords = loadSavedWords
    }

    func send(_ action: Action) {
        switch action {
        case .load:
            load()
        case .retry:
            index = nil
            load()
        case .queryChanged(let query):
            state.query = query
            updateResults()
        case .levelChanged(let level):
            state.level = level
            updateResults()
        case .clearFilters:
            state.query = ""
            state.level = nil
            updateResults()
        }
    }

    private func load() {
        state.loadState = .loading
        state.errorMessage = nil
        state.results = []
        state.savedWordsByCatalogID = [:]
        let loadedIndex: DictionarySearchIndex
        do {
            if let index {
                loadedIndex = index
            } else {
                let words = try loadCatalog().catalog.entries
                guard !words.isEmpty else {
                    fail("The bundled dictionary contains no study words. Try loading it again.")
                    return
                }
                loadedIndex = DictionarySearchIndex(words: words)
            }
        } catch {
            fail("The bundled dictionary couldn't be opened. Try again.")
            return
        }

        do {
            let saved = try loadSavedWords().sorted { $0.id < $1.id }
            var membership: [String: Kotoba] = [:]
            for word in saved {
                guard let catalogID = word.catalogID, membership[catalogID] == nil else { continue }
                // Legacy stores may contain several learner records for one study identity.
                membership[catalogID] = word
            }
            index = loadedIndex
            state.savedWordsByCatalogID = membership
            state.loadState = .loaded
            updateResults()
        } catch {
            fail("Your saved word collection couldn't be opened. Try again.")
        }
    }

    private func updateResults() {
        guard state.loadState == .loaded, let index else {
            state.results = []
            return
        }
        state.results = index.results(query: state.query, level: state.level)
    }

    private func fail(_ message: String) {
        index = nil
        state.results = []
        state.savedWordsByCatalogID = [:]
        state.errorMessage = message
        state.loadState = .failed
    }

    struct State {
        var query = ""
        var level: String?
        var results: [DictionaryWord] = []
        var savedWordsByCatalogID: [String: Kotoba] = [:]
        var loadState: TodayLoadState = .loading
        var errorMessage: String?
    }

    enum Action {
        case load
        case queryChanged(String)
        case levelChanged(String?)
        case clearFilters
        case retry
    }
}
