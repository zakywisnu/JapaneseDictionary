import XCTest
import SwiftData
@testable import DataKit

final class WordAdditionTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_750_000_000)
    private enum Failure: Error { case injected }

    func testSequentialAddUsesCatalogFieldsAndAdvancesOnce() throws {
        let store = try fixture()
        let result = try repository(store).addWord(catalogID: "first", savedID: "learner", addedAt: date, source: .next(expectedCursor: 0))
        XCTAssertEqual(result.kotobaIndex, 1)
        XCTAssertEqual(result.kotobaProgress, 1)
        let saved = try XCTUnwrap(store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first)
        XCTAssertEqual(saved.catalogID, "first"); XCTAssertEqual(saved.addedIndex, 0)
        XCTAssertEqual(saved.kanji, "森"); XCTAssertEqual(saved.english.map(\.value), ["forest"])
        XCTAssertEqual(saved.id, "learner"); XCTAssertEqual(saved.dateAdded, date)
    }

    func testSelectedDuplicatePreservesCursorLevelAndDateWithoutSaving() throws {
        let store = try fixture()
        var saves = 0
        let repo = try repository(store, save: { context in saves += 1; try context.save() })
        let first = try repo.addWord(catalogID: "later", savedID: "learner", addedAt: date, source: .selected)
        let duplicate = try repo.addWord(catalogID: "later", savedID: "other", addedAt: date.addingTimeInterval(100), source: .selected)
        XCTAssertEqual(first, duplicate); XCTAssertEqual(first.kotobaIndex, 0)
        XCTAssertEqual(first.kotobaLevel, "N5"); XCTAssertEqual(saves, 1)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
    }

    func testSequentialSkipsSelectedMembershipAndRejectsStaleOrWrongOffer() throws {
        let store = try fixture()
        let repo = try repository(store)
        _ = try repo.addWord(catalogID: "first", savedID: "chosen", addedAt: date, source: .selected)
        XCTAssertThrowsError(try repo.addWord(catalogID: "first", savedID: "wrong", addedAt: date, source: .next(expectedCursor: 0)))
        _ = try repo.addWord(catalogID: "later", savedID: "next", addedAt: date, source: .next(expectedCursor: 0))
        XCTAssertThrowsError(try repo.addWord(catalogID: "later", savedID: "stale", addedAt: date, source: .next(expectedCursor: 0)))
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaIndex, 2)
    }

    func testMissingFutureOrMultipleProgressAndInvalidInputCannotInsert() throws {
        for version in [nil, 99, 2] as [Int?] {
            let store = try StudyStore(inMemory: true)
            if let version {
                store.context.insert(progress(version: version))
                if version == 2 { let other = progress(version: 2); other.id = "other"; store.context.insert(other) }
                try store.context.save()
            }
            XCTAssertThrowsError(try repository(store).addWord(catalogID: "first", savedID: "learner", addedAt: date, source: .selected))
            XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).isEmpty)
        }
        let store = try fixture()
        let repo = try repository(store)
        XCTAssertThrowsError(try repo.addWord(catalogID: "missing", savedID: "learner", addedAt: date, source: .selected))
        XCTAssertThrowsError(try repo.addWord(catalogID: "first", savedID: "", addedAt: date, source: .selected))
        XCTAssertThrowsError(try repo.addWord(catalogID: "first", savedID: "learner", addedAt: Date(timeIntervalSince1970: .infinity), source: .selected))
        _ = try repo.addWord(catalogID: "first", savedID: "learner", addedAt: date, source: .selected)
        XCTAssertThrowsError(try repo.addWord(catalogID: "later", savedID: "learner", addedAt: date, source: .selected))
    }

    func testSaveFailureRollsBackWordAndProgressAndPrepareFailureDoesNotSave() throws {
        let store = try fixture()
        XCTAssertThrowsError(try repository(store, save: { _ in throw Failure.injected }).addWord(catalogID: "first", savedID: "learner", addedAt: date, source: .next(expectedCursor: 0)))
        XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).isEmpty)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaProgress, 0)
        let repo = StandardWordAdditionRepository(store: store, catalog: try catalog(), prepare: { throw Failure.injected })
        XCTAssertThrowsError(try repo.addWord(catalogID: "first", savedID: "learner", addedAt: date, source: .selected))
    }

    func testDiskRestartRetainsLearnerIDCatalogSlotAndCursor() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study.store")
        do {
            let store = try StudyStore(url: url)
            store.context.insert(progress()); try store.context.save()
            _ = try repository(store).addWord(catalogID: "later", savedID: "retained", addedAt: date, source: .selected)
        }
        let reopened = try StudyStore(url: url)
        let saved = try XCTUnwrap(reopened.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first)
        XCTAssertEqual(saved.id, "retained"); XCTAssertEqual(saved.catalogID, "later"); XCTAssertEqual(saved.addedIndex, 1)
        XCTAssertEqual(try reopened.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaIndex, 0)
    }

    func testDeletingLaterSelectedWordKeepsEarlierSequentialCursorAndLevel() throws {
        let store = try fixture()
        _ = try repository(store).addWord(catalogID: "later", savedID: "learner", addedAt: date, source: .selected)
        let result = try StandardStudyMutationRepository(store: store, catalogLevel: { _ in "N1" }).delete(id: .init(kind: .word, id: "learner"))
        XCTAssertEqual(result.kotobaIndex, 0); XCTAssertEqual(result.kotobaLevel, "N5")
        XCTAssertEqual(result.kotobaProgress, 0)
    }

    func testSelectedAdditionBackupRoundTripPreservesAnchorsAndUnrelatedStudyData() throws {
        let store = try fixture()
        let existing = KotobaDataModel(id: "existing-learner", kanji: "旧語", furigana: "きゅうご",
            english: [.init(value: "learner meaning")], jlptLevel: .n4, dateAdded: date.addingTimeInterval(-500),
            addedIndex: nil, memoryExplanation: "A word from an earlier dictionary.", memoryMnemonic: "Remember the old book.")
        let kanji = KanjiDataModel(id: "saved-kanji", kanji: "森", stroke: 12,
            onyomi: [.init(value: "シン")], kunyomi: [.init(value: "もり")], jlptLevel: .n5,
            meanings: [.init(value: "forest")], dateAdded: date.addingTimeInterval(-300), addedIndex: 0)
        let review = ReviewRecord(id: .init(kind: .word, id: existing.id), stage: 2,
            dueDate: date.addingTimeInterval(86_400), lastReviewedAt: date.addingTimeInterval(-100),
            lastSessionID: UUID(), sessionBaselineStage: 1, sessionHadAgain: false)
        store.context.insert(existing); store.context.insert(kanji)
        store.context.insert(ReviewRecordModel(record: review))
        let progress = try XCTUnwrap(store.context.fetch(FetchDescriptor<WordsProgressModel>()).first)
        progress.kotobaProgress = 1; progress.kanjiProgress = 1; progress.kanjiIndex = 1
        try store.context.save()
        let vocabulary = try catalog()
        let catalogWords = vocabulary.catalog.entries.enumerated().map { index, entry in
            KotobaDataModel(id: entry.id, kanji: entry.headword, furigana: entry.reading,
                english: entry.studyMeanings.map { ArrayString(value: $0) },
                jlptLevel: KotobaDataModel.Level(rawValue: entry.level)!, dateAdded: nil,
                addedIndex: index, catalogID: entry.id)
        }
        let snapshot = CatalogSnapshot(words: catalogWords, kanjis: [kanji], version: 2)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = BackupRepository(store: store, catalog: snapshot,
            recoveryURL: directory.appendingPathComponent("source-recovery.json"))
        let before = try source.validate(source.export(preferences: .init()))
        _ = try repository(store).addWord(catalogID: "later", savedID: "selected-learner", addedAt: date, source: .selected)
        let exported = try source.validate(source.export(preferences: .init(todayKind: .kanji)))
        let freshStore = try StudyStore(inMemory: true)
        let destination = BackupRepository(store: freshStore, catalog: snapshot,
            recoveryURL: directory.appendingPathComponent("restore-recovery.json"))
        try destination.restore(exported, currentPreferences: .init())
        let restored = try destination.validate(destination.export(preferences: exported.preferences))
        let selected = try XCTUnwrap(restored.words.first(where: { $0.id == "selected-learner" }))
        XCTAssertEqual(selected.catalogID, "later"); XCTAssertEqual(selected.addedIndex, 1)
        XCTAssertEqual(selected.dateAdded, date); XCTAssertEqual(selected.english, ["gloom"])
        XCTAssertNil(selected.memoryAid)
        XCTAssertEqual(restored.progress?.kotobaIndex, 0); XCTAssertEqual(restored.progress?.kotobaLevel, .n5)
        XCTAssertEqual(restored.progress?.kotobaProgress, 2); XCTAssertEqual(restored.progress?.lastKotobaUpdated, date)
        XCTAssertEqual(restored.words.first(where: { $0.id == existing.id }), before.words.first)
        XCTAssertEqual(restored.kanjis, before.kanjis); XCTAssertEqual(restored.reviews, before.reviews)
        XCTAssertEqual(restored.progress?.kanjiIndex, before.progress?.kanjiIndex)
        XCTAssertEqual(restored.progress?.kanjiProgress, before.progress?.kanjiProgress)
        XCTAssertEqual(restored.progress?.lastKanjiUpdated, before.progress?.lastKanjiUpdated)
        XCTAssertEqual(restored.words, exported.words); XCTAssertEqual(restored.progress, exported.progress)
        XCTAssertEqual(restored.preferences, exported.preferences)
    }

    private func fixture() throws -> StudyStore {
        let store = try StudyStore(inMemory: true)
        store.context.insert(progress()); try store.context.save()
        return store
    }
    private func progress(version: Int = 2) -> WordsProgressModel {
        .init(id: "progress", kanjiProgress: 0, kotobaProgress: 0, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 0, lastKotobaUpdated: date.addingTimeInterval(-100), lastKanjiUpdated: date, catalogVersion: version)
    }
    private func repository(_ store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) throws -> StandardWordAdditionRepository {
        .init(store: store, catalog: try catalog(), save: save)
    }
    private func catalog() throws -> VocabularyCatalogRepository {
        let entries = [("first", "森", "もり", "forest", "N5"), ("later", "鬱", "うつ", "gloom", "N1")].enumerated().map { index, item in
            DictionaryWord(id: item.0, jmdictID: index + 1, headword: item.1, reading: item.2, level: item.4, studyMeanings: [item.3], forms: [.init(text: item.1, notes: [], common: false)], readings: [.init(text: item.2, spellings: [item.1], notes: [], common: false, kanaOnly: false)], senses: [.init(meanings: [item.3], pos: [], labels: [], notes: [], spellings: [], readings: [])])
        }
        return try .init(catalog: .init(version: 2, created: "2026-10-08", jmdictCreated: "2026-10-08", entries: entries, legacyMap: []))
    }
}
