import XCTest
import DataKit
import SwiftData
@testable import DomainKit

final class WordAdditionUseCaseTests: XCTestCase {
    private enum Failure: Error { case injected }

    func testSelectedFailurePreservesProgressShadow() throws {
        let previous = UserDefaults.standard.object(forKey: "wordsProgress")
        defer { UserDefaults.standard.set(previous, forKey: "wordsProgress") }
        let sentinel = Data("existing progress".utf8)
        UserDefaults.standard.set(sentinel, forKey: "wordsProgress")
        XCTAssertThrowsError(try DefaultAddSelectedWordUseCase(additionRepository: FailingAddition()).execute(catalogID: "forest"))
        XCTAssertEqual(UserDefaults.standard.data(forKey: "wordsProgress"), sentinel)
    }

    func testSelectedSuccessPublishesReturnedPersistedProgress() throws {
        let previous = UserDefaults.standard.object(forKey: "wordsProgress")
        defer { UserDefaults.standard.set(previous, forKey: "wordsProgress") }
        let store = try StudyStore(inMemory: true)
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        store.context.insert(WordsProgressModel(id: "persisted", kanjiProgress: 3, kotobaProgress: 9, kanjiLevel: .n4, kotobaLevel: .n5, kanjiIndex: 7, kotobaIndex: 2, lastKotobaUpdated: date, lastKanjiUpdated: date, catalogVersion: 2))
        try store.context.save()
        let mutations = ReturningAddition(store: store)
        try DefaultAddSelectedWordUseCase(additionRepository: mutations, makeID: { "learner" }, now: { date }).execute(catalogID: "forest")
        XCTAssertEqual(mutations.catalogID, "forest"); XCTAssertEqual(mutations.savedID, "learner")
        XCTAssertEqual(mutations.date, date)
        let shadow = try JSONDecoder().decode(WordsProgressParam.self, from: XCTUnwrap(UserDefaults.standard.data(forKey: "wordsProgress")))
        XCTAssertEqual(shadow.id, "persisted"); XCTAssertEqual(shadow.kotobaIndex, 2); XCTAssertEqual(shadow.kotobaProgress, 9)
    }

    func testSequentialAdapterRejectsAlteredFieldsAndMissingExpectedCursorBeforeAdding() throws {
        let previous = UserDefaults.standard.object(forKey: "wordsProgress")
        defer { UserDefaults.standard.set(previous, forKey: "wordsProgress") }
        let entry = DictionaryWord(id: "forest", jmdictID: 1, headword: "森", reading: "もり", level: "N5", studyMeanings: ["forest"], forms: [.init(text: "森", notes: [], common: false)], readings: [.init(text: "もり", spellings: ["森"], notes: [], common: false, kanaOnly: false)], senses: [.init(meanings: ["forest"], pos: [], labels: [], notes: [], spellings: [], readings: [])])
        let catalog = try VocabularyCatalogRepository(catalog: .init(version: 2, created: "2026-10-08", jmdictCreated: "2026-10-08", entries: [entry], legacyMap: []))
        let store = try StudyStore(inMemory: true)
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        store.context.insert(WordsProgressModel(id: "progress", kanjiProgress: 0, kotobaProgress: 0, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 0, lastKotobaUpdated: date, lastKanjiUpdated: date, catalogVersion: 2))
        try store.context.save()
        let useCase = DefaultAddKotobaUseCase(additionRepository: StandardWordAdditionRepository(store: store, catalog: catalog), loadCatalog: { catalog })
        let progress = WordsProgressParam(id: "untrusted-shadow", kanjiProgress: 999, kotobaProgress: 999, kanjiLevel: .n5, kotobaLevel: .n5, lastKotobaUpdated: date, lastKanjiUpdated: date, kanjiIndex: 0, kotobaIndex: 1)
        var param = KotobaParam(id: "learner", kanji: "森", furigana: "もり", english: ["altered"], jlptLevel: .n5, dateAdded: date, addedIndex: 0, catalogID: "forest", expectedCursor: 0)
        XCTAssertThrowsError(try useCase.execute(param: param, progress: progress))
        param.english = ["forest"]; param.expectedCursor = nil
        XCTAssertThrowsError(try useCase.execute(param: param, progress: progress))
        XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).isEmpty)
        param.expectedCursor = 0
        try useCase.execute(param: param, progress: progress)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first?.catalogID, "forest")
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaIndex, 1)
        let shadow = try JSONDecoder().decode(WordsProgressParam.self, from: XCTUnwrap(UserDefaults.standard.data(forKey: "wordsProgress")))
        XCTAssertEqual(shadow.id, "progress"); XCTAssertEqual(shadow.kotobaProgress, 1); XCTAssertEqual(shadow.kanjiProgress, 0)
    }

    private struct FailingAddition: WordAdditionRepository {
        func addWord(catalogID: String, savedID: String, addedAt: Date, source: WordAdditionSource) throws -> StudyProgress { throw Failure.injected }
    }
    private final class ReturningAddition: WordAdditionRepository {
        let store: StudyStore
        var catalogID: String?; var savedID: String?; var date: Date?
        init(store: StudyStore) { self.store = store }
        func addWord(catalogID: String, savedID: String, addedAt: Date, source: WordAdditionSource) throws -> StudyProgress {
            guard case .selected = source else { throw Failure.injected }
            self.catalogID = catalogID; self.savedID = savedID; date = addedAt
            let context = store.makeContext()
            // A retired word lets the existing public mutation API return a persisted progress snapshot.
            context.insert(KotobaDataModel(id: "temporary", kanji: "旧語", furigana: "きゅうご", english: [.init(value: "retired")], jlptLevel: .n5, dateAdded: addedAt, addedIndex: nil))
            let progress = try XCTUnwrap(context.fetch(FetchDescriptor<WordsProgressModel>()).first)
            progress.kotobaProgress += 1
            try context.save()
            return try StandardStudyMutationRepository(context: context).delete(id: .init(kind: .word, id: "temporary"))
        }
    }
}
