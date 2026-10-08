import XCTest
import DataKit
@testable import SwiftUIApps

final class DictionaryBrowseTests: XCTestCase {
    func testDictionaryRoutesStayInTheNavigationStack() {
        XCTAssertTrue(AppRoutes.dictionary.isPushed)
        XCTAssertTrue(AppRoutes.dictionaryEntry("blue").isPushed)
        XCTAssertFalse(AppRoutes.dashboard.isPushed)
    }

    func testEmptyCatalogIsAResourceFailureWithRetry() throws {
        let empty = try VocabularyCatalogRepository(catalog: .init(created: "2026-10-07", jmdictCreated: "2026-10-07", entries: []))
        var catalog = empty
        let model = DictionaryBrowseViewModel(loadCatalog: { catalog }, loadSavedWords: { [] })
        model.send(.load)
        XCTAssertEqual(model.state.loadState, .failed)
        XCTAssertTrue(model.state.errorMessage?.contains("no study words") == true)
        catalog = try VocabularyCatalogRepository(catalog: .init(created: "2026-10-07", jmdictCreated: "2026-10-07", entries: [blue]))
        model.send(.retry)
        XCTAssertEqual(model.state.loadState, .loaded)
    }

    func testSearchIncludesSuppliedFormsReadingsAndEveryGlossWithoutRomanization() {
        let index = DictionarySearchIndex(words: [blue])
        for query in ["青い", "あおい", "蒼い", "  PALE\n BLUE  ", "inexperienced", "あをい"] {
            XCTAssertEqual(index.results(query: query, level: nil).map(\.id), [blue.id], query)
        }
        XCTAssertTrue(index.results(query: "aoi", level: nil).isEmpty)
        XCTAssertTrue(index.results(query: "obsolete", level: nil).isEmpty)
    }

    func testExactPrimaryThenPrimaryPrefixThenCatalogOrderAndDistinctSenses() {
        let alternate = word("alternate", headword: "別", reading: "べつ", meanings: ["blue"], forms: [.init(text: "別"), .init(text: "青")])
        let prefix = word("prefix", headword: "青空", reading: "あおぞら")
        let exact = word("exact", headword: "青", reading: "あお")
        let sense = word("other-sense", headword: "青", reading: "あお", meanings: ["green"])
        let index = DictionarySearchIndex(words: [alternate, prefix, exact, sense])
        XCTAssertEqual(index.results(query: "青", level: nil).map(\.id), [exact.id, sense.id, prefix.id, alternate.id])
        XCTAssertEqual(index.results(query: "あお", level: nil).map(\.id), [exact.id, sense.id, prefix.id])
        XCTAssertEqual(index.results(query: " \n ", level: nil).map(\.id), [alternate.id, prefix.id, exact.id, sense.id])
    }

    func testLevelFilterRunsForBlankAndMatchingQueriesAndUnknownLevelIsEmpty() {
        let harder = word("harder", headword: "青", reading: "あお", level: "N1")
        let index = DictionarySearchIndex(words: [blue, harder])
        XCTAssertEqual(index.results(query: "", level: "N1"), [harder])
        XCTAssertEqual(index.results(query: "青", level: "N5"), [blue])
        XCTAssertTrue(index.results(query: "", level: "N9").isEmpty)
    }

    func testBrowseRefreshesMembershipCachesCatalogAndChoosesLowestSavedID() throws {
        let catalog = try repository()
        var catalogLoads = 0
        var membership: [Kotoba] = [saved("z"), saved("a"), saved("retired", catalogID: nil)]
        let model = DictionaryBrowseViewModel(loadCatalog: { catalogLoads += 1; return catalog }, loadSavedWords: { membership })
        XCTAssertEqual(model.state.loadState, .loading)
        XCTAssertTrue(model.state.results.isEmpty)
        model.send(.load)
        XCTAssertEqual(model.state.loadState, .loaded)
        XCTAssertEqual(model.state.results, [blue])
        XCTAssertEqual(model.state.savedWordsByCatalogID[blue.id]?.id, "a")
        XCTAssertEqual(model.state.savedWordsByCatalogID.count, 1)
        model.send(.queryChanged("blue"))
        model.send(.levelChanged("N1"))
        XCTAssertTrue(model.state.results.isEmpty)
        model.send(.clearFilters)
        XCTAssertEqual(model.state.query, "")
        XCTAssertNil(model.state.level)
        XCTAssertEqual(model.state.results, [blue])
        membership = []
        model.send(.load)
        XCTAssertEqual(catalogLoads, 1)
        XCTAssertTrue(model.state.savedWordsByCatalogID.isEmpty)
    }

    func testResourceFailureBlocksResultsAndRetryReloadsBothSources() throws {
        let catalog = try repository()
        var attempts = 0
        var savedLoads = 0
        let model = DictionaryBrowseViewModel(loadCatalog: {
            attempts += 1
            if attempts == 1 { throw BrowseTestError.failed }
            return catalog
        }, loadSavedWords: { savedLoads += 1; return [] })
        model.send(.load)
        XCTAssertEqual(model.state.loadState, .failed)
        XCTAssertTrue(model.state.results.isEmpty)
        XCTAssertTrue(model.state.savedWordsByCatalogID.isEmpty)
        model.send(.queryChanged("blue"))
        XCTAssertTrue(model.state.results.isEmpty)
        model.send(.retry)
        XCTAssertEqual(model.state.loadState, .loaded)
        XCTAssertEqual(model.state.results, [blue])
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(savedLoads, 1)
    }

    func testMembershipFailureDiscardsStaleResultsAndRetryReloadsCatalog() throws {
        let catalog = try repository()
        var catalogLoads = 0
        var fails = false
        let model = DictionaryBrowseViewModel(loadCatalog: { catalogLoads += 1; return catalog }, loadSavedWords: {
            if fails { throw BrowseTestError.failed }
            return [self.saved("saved")]
        })
        model.send(.load)
        fails = true
        model.send(.load)
        XCTAssertEqual(model.state.loadState, .failed)
        XCTAssertTrue(model.state.results.isEmpty)
        XCTAssertTrue(model.state.savedWordsByCatalogID.isEmpty)
        model.send(.clearFilters)
        XCTAssertTrue(model.state.results.isEmpty)
        fails = false
        model.send(.retry)
        XCTAssertEqual(model.state.loadState, .loaded)
        XCTAssertEqual(model.state.savedWordsByCatalogID[blue.id]?.id, "saved")
        XCTAssertEqual(catalogLoads, 2)
    }

    private var blue: DictionaryWord {
        .init(id: "blue", jmdictID: 1, headword: "青い", reading: "あおい", level: "N5", studyMeanings: ["blue"], forms: [.init(text: "青い"), .init(text: "蒼い")], readings: [.init(text: "あおい", spellings: ["青い"]), .init(text: "あをい", spellings: ["蒼い"], notes: ["obsolete"])], senses: [.init(meanings: ["blue", "pale blue"], spellings: ["青い"], readings: ["あおい"]), .init(meanings: ["inexperienced"], spellings: ["蒼い"], readings: ["あをい"])])
    }

    private func word(_ id: String, headword: String, reading: String, level: String = "N5", meanings: [String] = ["blue"], forms: [DictionaryForm]? = nil) -> DictionaryWord {
        .init(id: id, jmdictID: 2, headword: headword, reading: reading, level: level, studyMeanings: meanings, forms: forms ?? [.init(text: headword)], readings: [.init(text: reading)], senses: [.init(meanings: meanings)])
    }

    private func repository() throws -> VocabularyCatalogRepository {
        try .init(catalog: .init(created: "2026-10-08", jmdictCreated: "2026-10-08", entries: [blue]))
    }

    private func saved(_ id: String, catalogID: String? = "blue") -> Kotoba {
        .init(id: id, kanji: "青い", furigana: "あおい", english: ["saved meaning"], jlptLevel: .n5, dateAdded: .distantPast, addedIndex: 0, catalogID: catalogID)
    }
}

private enum BrowseTestError: Error { case failed }
