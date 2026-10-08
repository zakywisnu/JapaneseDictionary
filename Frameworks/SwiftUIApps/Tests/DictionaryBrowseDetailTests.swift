import XCTest
import DataKit
@testable import SwiftUIApps

final class DictionaryBrowseDetailTests: XCTestCase {
    private enum Failure: Error { case injected }
    private var entry: DictionaryWord {
        .init(id: "blue", jmdictID: 1, headword: "青い", reading: "あおい", level: "N5",
              studyMeanings: ["blue"], forms: [.init(text: "青い")],
              readings: [.init(text: "あおい")], senses: [.init(meanings: ["blue"])])
    }
    private var saved: Kotoba {
        .init(id: "learner", kanji: "青い", furigana: "あおい", english: ["saved meaning"],
              jlptLevel: .n5, dateAdded: .distantPast, addedIndex: 0, catalogID: "blue")
    }
    private func catalog() throws -> VocabularyCatalogRepository {
        try .init(catalog: .init(created: "2026-10-07", jmdictCreated: "2026-10-07", entries: [entry]))
    }

    func testAddReloadsSavedIdentityAndRepeatedTapDoesNotAddAgain() throws {
        let catalog = try catalog()
        var savedWords: [Kotoba] = []
        var calls = 0
        let saved = saved
        let model = DictionaryBrowseDetailViewModel(catalogID: "blue", loadCatalog: { catalog },
            loadSavedWords: { savedWords }, addWord: { id in
                XCTAssertEqual(id, "blue"); calls += 1; savedWords = [saved]
            })
        model.send(.load)
        XCTAssertEqual(model.state.word, entry)
        XCTAssertTrue(model.canAdd)
        model.send(.add)
        XCTAssertEqual(model.state.savedWord?.id, "learner")
        XCTAssertTrue(model.state.didAdd)
        model.send(.add)
        XCTAssertEqual(calls, 1)
    }

    func testSaveFailureKeepsEntryAndRetryableAction() throws {
        let catalog = try catalog()
        let model = DictionaryBrowseDetailViewModel(catalogID: "blue", loadCatalog: { catalog },
            loadSavedWords: { [] }, addWord: { _ in throw Failure.injected })
        model.send(.load); model.send(.add)
        XCTAssertEqual(model.state.word, entry)
        XCTAssertTrue(model.canAdd)
        XCTAssertNotNil(model.state.errorMessage)
        XCTAssertFalse(model.state.didAdd)
    }

    func testResourceOrMembershipFailureDisablesAdditionUntilRetry() throws {
        let catalog = try catalog()
        var fails = true
        var calls = 0
        let model = DictionaryBrowseDetailViewModel(catalogID: "blue", loadCatalog: { catalog },
            loadSavedWords: { if fails { throw Failure.injected }; return [] }, addWord: { _ in calls += 1 })
        model.send(.load); model.send(.add)
        XCTAssertTrue(model.state.loadState == .failed)
        XCTAssertFalse(model.canAdd); XCTAssertEqual(calls, 0)
        fails = false; model.send(.load)
        XCTAssertTrue(model.canAdd)
    }

    func testExistingSavedContextAndMissingEntryNeverOfferAdd() throws {
        let catalog = try catalog()
        let saved = saved
        let existing = DictionaryBrowseDetailViewModel(catalogID: "blue", loadCatalog: { catalog },
            loadSavedWords: { [saved] }, addWord: { _ in XCTFail("already collected") })
        existing.send(.load); existing.send(.add)
        XCTAssertEqual(existing.state.savedWord?.english, ["saved meaning"])
        XCTAssertFalse(existing.canAdd)
        let missing = DictionaryBrowseDetailViewModel(catalogID: "missing", loadCatalog: { catalog },
            loadSavedWords: { [] }, addWord: { _ in XCTFail("missing entry") })
        missing.send(.load); missing.send(.add)
        XCTAssertNil(missing.state.word); XCTAssertFalse(missing.canAdd)
    }

    func testCommittedAddWithFailedReloadDisablesAnotherAddAndRetriesMembership() throws {
        let catalog = try catalog()
        let saved = saved
        var added = false
        var reloadFails = true
        var calls = 0
        let model = DictionaryBrowseDetailViewModel(catalogID: "blue", loadCatalog: { catalog },
            loadSavedWords: {
                if added && reloadFails { throw Failure.injected }
                return added ? [saved] : []
            }, addWord: { _ in added = true; calls += 1 })
        model.send(.load); model.send(.add); model.send(.add)
        XCTAssertTrue(model.state.didAdd); XCTAssertFalse(model.canAdd)
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(model.state.loadError?.contains("was added") == true)
        reloadFails = false; model.send(.load)
        XCTAssertEqual(model.state.savedWord?.id, "learner")
        XCTAssertFalse(model.canAdd)
    }
}
