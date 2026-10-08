import XCTest
import DataKit
import DomainKit
@testable import SwiftUIApps

final class DictionaryDetailTests: XCTestCase {
    func testMetadataLoadingDoesNotChangeSavedStudyContext() throws {
        let original = savedWord
        let update = DictionaryUpdateSpy()
        let model = makeModel(original, updater: update, catalog: try catalog([dictionaryWord]))
        model.send(.loadDictionary)
        XCTAssertEqual(model.state.dictionary, .linked(dictionaryWord))
        XCTAssertEqual(model.state.kotoba, original)
        XCTAssertTrue(update.calls.isEmpty)
        XCTAssertEqual(model.state.studyUpdate?.english, ["new study meaning"])
    }

    func testExplicitUpdatePreservesLearnerIdentityAndAnchors() throws {
        let original = savedWord
        let update = DictionaryUpdateSpy()
        let model = makeModel(original, updater: update, catalog: try catalog([dictionaryWord]))
        model.send(.loadDictionary)
        model.send(.confirmStudyUpdate)
        let param = try XCTUnwrap(update.calls.first)
        XCTAssertEqual(param.id, original.id)
        XCTAssertEqual(param.dateAdded, original.dateAdded)
        XCTAssertEqual(param.addedIndex, original.addedIndex)
        XCTAssertEqual(param.catalogID, original.catalogID)
        XCTAssertEqual(param.english, dictionaryWord.studyMeanings)
        XCTAssertEqual(model.state.kotoba?.english, dictionaryWord.studyMeanings)
        XCTAssertTrue(model.state.didUpdateStudyWord)
    }

    func testUpdateFailureRetainsSavedContextForMemoryHelper() throws {
        let update = DictionaryUpdateSpy()
        update.fails = true
        let model = makeModel(savedWord, updater: update, catalog: try catalog([dictionaryWord]))
        model.send(.loadDictionary)
        model.send(.confirmStudyUpdate)
        XCTAssertEqual(model.state.kotoba, savedWord)
        XCTAssertFalse(model.state.didUpdateStudyWord)
        XCTAssertNotNil(model.state.errorMessage)
    }

    func testAmbiguousHomographCannotBeUsedAsReplacement() throws {
        var saved = savedWord
        saved.catalogID = nil
        saved.english = ["unmatched saved context"]
        let second = DictionaryWord(id: "jmdict:2", jmdictID: 2, headword: "明日", reading: "あした", level: "N4", studyMeanings: ["another sense"], forms: [.init(text: "明日")], readings: [.init(text: "あした")], senses: [.init(meanings: ["another sense"])])
        let update = DictionaryUpdateSpy()
        let model = makeModel(saved, updater: update, catalog: try catalog([dictionaryWord, second]))
        model.send(.loadDictionary)
        XCTAssertEqual(model.state.dictionary, .ambiguous)
        XCTAssertNil(model.state.studyUpdate)
        model.send(.confirmStudyUpdate)
        XCTAssertTrue(update.calls.isEmpty)
        XCTAssertEqual(model.state.kotoba, saved)
    }

    func testResourceFailureCanRetryWithoutLosingSavedWord() throws {
        let catalog = try catalog([dictionaryWord])
        var attempts = 0
        let model = DetailViewModel(.init(kotoba: savedWord, kanji: nil), deleteKanjiUseCase: DictionaryDeleteKanji(), deleteKotobaUseCase: DictionaryDeleteWord(), loadCatalog: {
            attempts += 1
            if attempts == 1 { throw DictionaryTestError.failed }
            return catalog
        })
        model.send(.loadDictionary)
        XCTAssertEqual(model.state.dictionary, .failed)
        XCTAssertEqual(model.state.kotoba, savedWord)
        model.send(.loadDictionary)
        XCTAssertEqual(model.state.dictionary, .linked(dictionaryWord))
    }

    @MainActor
    func testAddNextSkipsCatalogWordSavedOnPreviousDayWithDifferentLearnerID() {
        let first = KotobaDataModel(id: "bundle-1", kanji: "明日", furigana: "あした", english: [.init(value: "tomorrow")], jlptLevel: .n5, dateAdded: nil, addedIndex: nil, catalogID: "catalog-1")
        let second = KotobaDataModel(id: "bundle-2", kanji: "今日", furigana: "きょう", english: [.init(value: "today")], jlptLevel: .n5, dateAdded: nil, addedIndex: nil, catalogID: "catalog-2")
        let previouslySaved = KotobaDataModel(id: "learner-1", kanji: "明日", furigana: "あした", english: [.init(value: "tomorrow")], jlptLevel: .n5, dateAdded: .distantPast, addedIndex: 0, catalogID: "catalog-1")
        let add = DictionaryAddSpy()
        let model = HomeKotobaViewModel(getKotobaDataUseCase: DictionaryBundledWords(words: [first, second]), getAllKotobaUseCase: DictionarySavedWords(words: [previouslySaved]), getWordsProgressUseCase: DictionaryProgress(fails: false), addKotobaUseCase: add, deleteKotobaUseCase: DictionaryDeleteWord(), getDueReviewsUseCase: DictionaryDueReviews())
        model.send(.onAppear)
        XCTAssertTrue(model.state.currentKotobas.isEmpty)
        XCTAssertEqual(model.state.savedCatalogIDs, ["catalog-1"])
        model.send(.didTapAdd)
        XCTAssertEqual(add.calls.first?.catalogID, "catalog-2")
        XCTAssertNotEqual(add.calls.first?.id, "bundle-2")
        XCTAssertEqual(add.calls.first?.addedIndex, 1)
    }

    @MainActor
    func testProgressFailureCannotBeHiddenBySuccessfulCollectionLoad() {
        let word = KotobaDataModel(id: "bundle-1", kanji: "明日", furigana: "あした", english: [.init(value: "tomorrow")], jlptLevel: .n5, dateAdded: nil, addedIndex: nil, catalogID: "catalog-1")
        let add = DictionaryAddSpy()
        let model = HomeKotobaViewModel(getKotobaDataUseCase: DictionaryBundledWords(words: [word]), getAllKotobaUseCase: DictionarySavedWords(words: []), getWordsProgressUseCase: DictionaryProgress(fails: true), addKotobaUseCase: add, deleteKotobaUseCase: DictionaryDeleteWord(), getDueReviewsUseCase: DictionaryDueReviews())
        model.send(.onAppear)
        XCTAssertTrue(model.state.loadState == .failed)
        XCTAssertNil(model.state.progress)
        model.send(.didTapAdd)
        XCTAssertTrue(add.calls.isEmpty)
        XCTAssertTrue(model.state.loadState == .failed)
    }

    private var savedWord: Kotoba {
        .init(id: "learner-id", kanji: "明日", furigana: "あした", english: ["saved study meaning"], jlptLevel: .n5, dateAdded: Date(timeIntervalSince1970: 12345), addedIndex: 42, catalogID: "jmdict:1")
    }

    private var dictionaryWord: DictionaryWord {
        .init(id: "jmdict:1", jmdictID: 1, headword: "明日", reading: "あした", level: "N5", studyMeanings: ["new study meaning"], forms: [.init(text: "明日")], readings: [.init(text: "あした"), .init(text: "あす")], senses: [.init(meanings: ["new study meaning"], pos: ["noun"])])
    }

    private func catalog(_ entries: [DictionaryWord]) throws -> VocabularyCatalogRepository {
        try .init(catalog: .init(created: "2026-10-07", jmdictCreated: "2026-10-07", entries: entries))
    }

    private func makeModel(_ word: Kotoba, updater: DictionaryUpdateSpy, catalog: VocabularyCatalogRepository) -> DetailViewModel {
        .init(.init(kotoba: word, kanji: nil), deleteKanjiUseCase: DictionaryDeleteKanji(), deleteKotobaUseCase: DictionaryDeleteWord(), updateKotobaUseCase: updater, catalog: catalog)
    }
}

private enum DictionaryTestError: Error { case failed }
private final class DictionaryUpdateSpy: UpdateKotobaUseCase {
    var calls: [KotobaParam] = []
    var fails = false
    func execute(_ param: KotobaParam) throws {
        if fails { throw DictionaryTestError.failed }
        calls.append(param)
    }
}
private struct DictionaryDeleteWord: DeleteKotobaUseCase {
    func execute(kotoba: KotobaParam) throws {}
}
private struct DictionaryDeleteKanji: DeleteKanjiUseCase {
    func execute(param: KanjiParam) throws {}
}

private struct DictionaryBundledWords: GetKotobaDataUseCase {
    let words: [KotobaDataModel]
    func execute() throws -> [KotobaDataModel] { words }
}
private struct DictionarySavedWords: GetAllKotobaUseCase {
    let words: [KotobaDataModel]
    func execute() throws -> [KotobaDataModel] { words }
}
private struct DictionaryProgress: GetWordsProgressUseCase {
    let fails: Bool
    func execute() throws -> WordsProgressModel {
        if fails { throw DictionaryTestError.failed }
        return .init(id: "progress", kanjiProgress: 0, kotobaProgress: 1, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 0, lastKotobaUpdated: .distantPast, lastKanjiUpdated: .distantPast)
    }
}
private final class DictionaryAddSpy: AddKotobaUseCase {
    var calls: [KotobaParam] = []
    func execute(param: KotobaParam, progress: WordsProgressParam) throws { calls.append(param) }
}
private struct DictionaryDueReviews: GetDueReviewsUseCase {
    func execute(kind: SavedStudyKind, now: Date) throws -> [DueReview] { [] }
}
