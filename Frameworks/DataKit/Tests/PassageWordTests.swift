import XCTest
import SwiftData
@testable import DataKit

final class PassageWordTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 100_000)
    private enum Failure: Error { case injected }
    func testAtomicFailureRollsBackWordListMembershipAndProgress() throws {
        let store = try fixture()
        let repository = try repository(store, save: { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
            XCTAssertEqual(try context.fetch(FetchDescriptor<StudyItemMembershipModel>()).count, 1)
            throw Failure.injected
        })
        XCTAssertThrowsError(try repository.save(catalogID: "sense-1", passageID: "morning", title: "Morning"))
        let context = store.makeContext()
        XCTAssertTrue(try context.fetch(FetchDescriptor<KotobaDataModel>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<StudyListModel>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<StudyItemMembershipModel>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaProgress, 0)
    }
    func testRepeatedSaveUsesStableListAfterRenameAndPreservesSavedWord() throws {
        let store = try fixture(), repository = try repository(store)
        let first = try repository.save(catalogID: "sense-1", passageID: "morning", title: "Morning")
        let list = try XCTUnwrap(repository.list(passageID: "morning"))
        try StandardStudyListRepository(store: store).rename(id: list.id, name: "My renamed list")
        let context = store.makeContext()
        let word = try XCTUnwrap(context.fetch(FetchDescriptor<KotobaDataModel>()).first)
        word.english = [.init(value: "My learner meaning")]
        let originalDate = word.dateAdded
        try context.save()
        let second = try repository.save(catalogID: "sense-1", passageID: "morning", title: "Changed passage title")
        XCTAssertEqual(first, second)
        XCTAssertEqual(try repository.list(passageID: "morning")?.id, list.id)
        XCTAssertEqual(try repository.list(passageID: "morning")?.name, "My renamed list")
        XCTAssertEqual(try repository.list(passageID: "morning")?.itemCount, 1)
        let saved = try XCTUnwrap(store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first)
        XCTAssertEqual(saved.english.map(\.value), ["My learner meaning"])
        XCTAssertEqual(saved.dateAdded, originalDate)
        let progress = try XCTUnwrap(store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first)
        XCTAssertEqual(progress.kotobaIndex, 0); XCTAssertEqual(progress.kotobaLevel, .n5); XCTAssertEqual(progress.kotobaProgress, 1)
    }
    func testDistinctSensesAndSameTitlePassagesRemainDistinct() throws {
        let store = try fixture(), repository = try repository(store)
        let first = try repository.save(catalogID: "sense-1", passageID: "one", title: "A passage")
        let second = try repository.save(catalogID: "sense-2", passageID: "one", title: "A passage")
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try repository.list(passageID: "one")?.itemCount, 2)
        let repeated = try repository.save(catalogID: "sense-1", passageID: "two", title: "A passage")
        XCTAssertEqual(first, repeated)
        XCTAssertNotEqual(try repository.list(passageID: "one")?.id, try repository.list(passageID: "two")?.id)
        XCTAssertNotEqual(try repository.list(passageID: "one")?.name, try repository.list(passageID: "two")?.name)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 2)
    }
    func testListDeletionRetainsVocabularyAndNextSaveCreatesNewList() throws {
        let store = try fixture(), repository = try repository(store)
        let first = try repository.save(catalogID: "sense-1", passageID: "morning", title: "Morning")
        let list = try XCTUnwrap(repository.list(passageID: "morning"))
        try StandardStudyListRepository(store: store).delete(id: list.id)
        XCTAssertNil(try repository.list(passageID: "morning"))
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
        XCTAssertEqual(try repository.save(catalogID: "sense-1", passageID: "morning", title: "Morning"), first)
        XCTAssertNotEqual(try repository.list(passageID: "morning")?.id, list.id)
    }
    func testDiskReopenPreservesSourceKeyAndMembership() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study.store")
        let id: SavedStudyID
        do {
            let store = try fixture(url: url)
            id = try repository(store).save(catalogID: "sense-1", passageID: "morning", title: "Morning")
        }
        let reopened = try StudyStore(url: url), repository = try repository(reopened)
        XCTAssertEqual(try repository.list(passageID: "morning")?.sourceKey, "passage:morning")
        XCTAssertEqual(try repository.list(passageID: "morning")?.itemCount, 1)
        XCTAssertEqual(try repository.save(catalogID: "sense-1", passageID: "morning", title: "Morning"), id)
    }
    func testInvalidInputAndPrepareFailureCannotSave() throws {
        let store = try fixture(), repository = try repository(store)
        XCTAssertThrowsError(try repository.save(catalogID: "missing", passageID: "morning", title: "Morning"))
        XCTAssertThrowsError(try repository.save(catalogID: "sense-1", passageID: "", title: "Morning"))
        XCTAssertThrowsError(try repository.save(catalogID: "sense-1", passageID: String(repeating: "x", count: 249), title: "Morning"))
        XCTAssertThrowsError(try repository.save(catalogID: "sense-1", passageID: "morning", title: ""))
        let failed = StandardPassageWordRepository(store: store, catalog: try catalog(), prepare: { throw Failure.injected })
        XCTAssertThrowsError(try failed.save(catalogID: "sense-1", passageID: "morning", title: "Morning"))
        XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).isEmpty)
    }
    func testCanonicalDuplicateUsesEarliestDateThenIdentity() throws {
        let store = try fixture()
        for (id, added) in [("later", date), ("early-b", date.addingTimeInterval(-100)), ("early-a", date.addingTimeInterval(-100))] {
            store.context.insert(KotobaDataModel(id: id, kanji: "森", furigana: "もり", english: [.init(value: "forest")], jlptLevel: .n5, dateAdded: added, addedIndex: 0, catalogID: "sense-1"))
        }
        try store.context.save()
        let selected = try repository(store).save(catalogID: "sense-1", passageID: "morning", title: "Morning")
        XCTAssertEqual(selected.id, "early-a")
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 3)
    }
    private func fixture(url: URL? = nil) throws -> StudyStore {
        let store = try url.map { try StudyStore(url: $0) } ?? StudyStore(inMemory: true)
        store.context.insert(WordsProgressModel(id: "progress", kanjiProgress: 0, kotobaProgress: 0, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 0, lastKotobaUpdated: date.addingTimeInterval(-100), lastKanjiUpdated: date, catalogVersion: 2))
        try store.context.save(); return store
    }
    private func repository(_ store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) throws -> StandardPassageWordRepository {
        .init(store: store, catalog: try catalog(), save: save, now: { self.date })
    }
    private func catalog() throws -> VocabularyCatalogRepository {
        let words = [("sense-1", "forest"), ("sense-2", "woods")].map { id, meaning in
            DictionaryWord(id: id, jmdictID: 1, headword: "森", reading: "もり", level: "N5", studyMeanings: [meaning], forms: [.init(text: "森", notes: [], common: false)], readings: [.init(text: "もり", spellings: ["森"], notes: [], common: false, kanaOnly: false)], senses: [.init(meanings: [meaning], pos: [], labels: [], notes: [], spellings: [], readings: [])])
        }
        return try .init(catalog: .init(version: 2, created: "2026-10-10", jmdictCreated: "2026-10-10", entries: words, legacyMap: []))
    }
}
