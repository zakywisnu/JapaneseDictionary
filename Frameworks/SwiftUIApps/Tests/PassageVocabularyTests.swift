import XCTest
import DataKit
@testable import SwiftUIApps

final class PassageVocabularyTests: XCTestCase {
    enum Failure: Error { case save }
    private let context = PassageContext(id: "morning", title: "A quiet morning")
    private func word(_ id: String, meaning: String) -> DictionaryWord {
        .init(id: id, jmdictID: 1, headword: "青", reading: "あお", level: "N5", studyMeanings: [meaning], forms: [.init(text: "青")], readings: [.init(text: "あお")], senses: [.init(meanings: [meaning])])
    }
    private func catalog() throws -> VocabularyCatalogRepository {
        try .init(catalog: .init(created: "2026-10-07", jmdictCreated: "2026-10-07", entries: [word("blue", meaning: "blue"), word("green", meaning: "green")]))
    }
    func testAmbiguousVocabularySearchRequiresExplicitSenseSelection() throws {
        let catalog = try catalog()
        let model = DictionaryBrowseViewModel(loadCatalog: { catalog }, loadSavedWords: { [] })
        model.send(.queryChanged("青")); model.send(.load)
        XCTAssertEqual(Set(model.state.results.map(\.id)), ["blue", "green"])
        XCTAssertEqual(model.state.results.count, 2)
        XCTAssertTrue(model.state.savedWordsByCatalogID.isEmpty)
    }
    func testExistingSavedWordStillCanSaveToPassageAndFailureIsRetryable() throws {
        let catalog = try catalog()
        let saved = Kotoba(id: "learner", kanji: "青", furigana: "あお", english: ["learner meaning"], jlptLevel: .n5, dateAdded: .distantPast, addedIndex: 0, catalogID: "green")
        var fails = true
        var selected: [String] = []
        let model = DictionaryBrowseDetailViewModel(catalogID: "green", loadCatalog: { catalog }, loadSavedWords: { [saved] }, addWord: { _ in XCTFail("Existing word") }, passageContext: context, savePassageWord: { id, passage in
            XCTAssertEqual(passage, self.context); selected.append(id)
            if fails { throw Failure.save }
        })
        model.send(.load)
        XCTAssertFalse(model.canAdd)
        XCTAssertTrue(model.canSaveToPassage)
        model.send(.saveToPassage)
        XCTAssertTrue(model.canSaveToPassage)
        XCTAssertNotNil(model.state.errorMessage)
        XCTAssertFalse(model.state.didSaveToPassage)
        XCTAssertEqual(model.state.savedWord?.english, ["learner meaning"])
        fails = false; model.send(.saveToPassage)
        XCTAssertTrue(model.state.didSaveToPassage)
        XCTAssertFalse(model.canSaveToPassage)
        model.send(.saveToPassage)
        XCTAssertEqual(selected, ["green", "green"])
    }
    func testCommittedPassageSaveReloadFailureDoesNotOfferDuplicateSave() throws {
        let catalog = try catalog()
        var committed = false
        var fails = true
        var calls = 0
        let model = DictionaryBrowseDetailViewModel(catalogID: "blue", loadCatalog: { catalog }, loadSavedWords: {
            if committed && fails { throw Failure.save }; return []
        }, addWord: { _ in XCTFail() }, passageContext: context, savePassageWord: { _, _ in committed = true; calls += 1 })
        model.send(.load); model.send(.saveToPassage)
        XCTAssertTrue(model.state.didSaveToPassage)
        XCTAssertEqual(model.state.loadState, .failed)
        XCTAssertFalse(model.canSaveToPassage)
        fails = false; model.send(.load); model.send(.saveToPassage)
        XCTAssertEqual(calls, 1)
    }
    func testPassageCountReloadsActualMembershipAndMissingListIsZero() {
        var list: StudyList? = .init(id: "list", name: "Renamed", createdAt: .distantPast, wordCount: 2, sourceKey: "passage:morning")
        var fails = false
        let model = PassageVocabularyViewModel(load: { if fails { throw Failure.save }; return list })
        model.send(.load)
        XCTAssertEqual(model.state.savedCount, 2)
        XCTAssertEqual(model.state.list?.name, "Renamed")
        fails = true; model.send(.load)
        XCTAssertNotNil(model.state.error)
        XCTAssertNil(model.state.list)
        fails = false; list = nil; model.send(.load)
        XCTAssertEqual(model.state.savedCount, 0)
        XCTAssertNil(model.state.error)
    }
}
