import XCTest
import SwiftData
@testable import DataKit

final class StudyBackupTests: XCTestCase {
    func testRoundTripAndReplacementPreserveValues() throws {
        let store = try StudyStore(inMemory: true)
        let catalog = CatalogSnapshot(words: [word()], kanjis: [kanji()])
        store.context.insert(word())
        store.context.insert(kanji())
        store.context.insert(progress())
        store.context.insert(ReviewRecordModel(record: ReviewRecord(id: .init(kind: .word, id: "word"), stage: 2, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: 1, sessionHadAgain: false)))
        try store.context.save()
        let repository = BackupRepository(store: store, catalog: catalog, recoveryURL: recoveryURL())
        let preferences = BackupPreferences(todayKind: .kanji, collectionKind: .words)
        let data = try repository.export(preferences: preferences)
        let original = try repository.validate(data)
        store.context.insert(KotobaDataModel(id: "changed", kanji: "新", furigana: "しん", english: [], jlptLevel: .n5, dateAdded: nil, addedIndex: nil))
        try store.context.save()
        try repository.restore(original, currentPreferences: preferences)
        let restored = try repository.validate(repository.export(preferences: preferences))
        XCTAssertEqual(restored.words, original.words)
        XCTAssertEqual(restored.kanjis, original.kanjis)
        XCTAssertEqual(restored.progress, original.progress)
        XCTAssertEqual(restored.reviews, original.reviews)
        XCTAssertEqual(restored.preferences, original.preferences)
    }

    func testRejectsInvalidBackupWithoutMutatingStore() throws {
        let store = try StudyStore(inMemory: true)
        let catalog = CatalogSnapshot(words: [word()], kanjis: [kanji()])
        store.context.insert(word())
        store.context.insert(progress())
        try store.context.save()
        let repository = BackupRepository(store: store, catalog: catalog, recoveryURL: recoveryURL())
        let valid = try repository.validate(repository.export(preferences: .init()))
        var bad = valid
        bad.words.append(valid.words[0])
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        bad = valid; bad.formatVersion = 2
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        bad = valid; bad.catalogFingerprint = "foreign"
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        bad = valid; bad.words[0].addedIndex = 1
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        bad = valid; bad.createdAt = Date(timeIntervalSince1970: .infinity)
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        XCTAssertThrowsError(try repository.validate(Data("{".utf8)))
        XCTAssertThrowsError(try repository.validate(Data(repeating: 0, count: 20 * 1024 * 1024 + 1)))
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
    }

    func testSaveFailureRollsBackReplacementAndKeepsRecovery() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(word()); store.context.insert(progress()); try store.context.save()
        let catalog = CatalogSnapshot(words: [word()], kanjis: [kanji()])
        let recovery = recoveryURL()
        let repository = BackupRepository(store: store, catalog: catalog, recoveryURL: recovery, save: { _ in throw Failure.injected })
        var replacement = try repository.validate(repository.export(preferences: .init()))
        replacement.words = []
        XCTAssertThrowsError(try repository.restore(replacement, currentPreferences: .init()))
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).map(\.id), ["word"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.path))
    }

    func testRecoveryFailurePreventsAnySave() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(word()); store.context.insert(progress()); try store.context.save()
        let catalog = CatalogSnapshot(words: [word()], kanjis: [kanji()])
        var saved = false
        let repository = BackupRepository(store: store, catalog: catalog, recoveryURL: recoveryURL(), save: { _ in saved = true }, writeRecovery: { _, _ in throw Failure.injected })
        var replacement = try repository.validate(repository.export(preferences: .init()))
        replacement.words = []
        XCTAssertThrowsError(try repository.restore(replacement, currentPreferences: .init()))
        XCTAssertFalse(saved)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
    }

    func testFreshStoreExportsAbsentProgressAndSemanticFingerprintIgnoresIDs() throws {
        let store = try StudyStore(inMemory: true)
        let first = CatalogSnapshot(words: [word()], kanjis: [kanji()])
        let otherWord = word(); otherWord.id = "random"
        let otherKanji = kanji(); otherKanji.id = "another"
        let second = CatalogSnapshot(words: [otherWord], kanjis: [otherKanji])
        XCTAssertEqual(first.fingerprint, second.fingerprint)
        let repository = BackupRepository(store: store, catalog: first, recoveryURL: recoveryURL())
        XCTAssertNil(try repository.validate(repository.export(preferences: .init())).progress)
    }

    func testRejectsOrphanAndInvalidStagesAndCounters() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(word()); store.context.insert(progress()); try store.context.save()
        let repository = BackupRepository(store: store, catalog: CatalogSnapshot(words: [word()], kanjis: [kanji()]), recoveryURL: recoveryURL())
        let valid = try repository.validate(repository.export(preferences: .init()))
        var bad = valid
        bad.reviews = [ReviewRecord(id: .init(kind: .word, id: "missing"), stage: 0, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: nil, sessionHadAgain: false)]
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        bad.reviews = [ReviewRecord(id: .init(kind: .word, id: "word"), stage: 5, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: nil, sessionHadAgain: false)]
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        bad = valid; bad.progress?.kanjiProgress = -1
        XCTAssertThrowsError(try repository.restore(bad, currentPreferences: .init()))
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kanjiProgress, 9)
    }

    func testOnDiskReplacementSurvivesReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fixture.store")
        let catalog = CatalogSnapshot(words: [word()], kanjis: [kanji()])
        var original: StudyBackup!
        do {
            let store = try StudyStore(url: url)
            store.context.insert(word()); store.context.insert(kanji()); store.context.insert(progress())
            try store.context.save()
            let repository = BackupRepository(store: store, catalog: catalog, recoveryURL: directory.appendingPathComponent("recovery.json"))
            original = try repository.validate(repository.export(preferences: .init()))
            for item in try store.context.fetch(FetchDescriptor<KotobaDataModel>()) { store.context.delete(item) }
            try store.context.save()
            try repository.restore(original, currentPreferences: .init())
            XCTAssertEqual(try store.context.fetch(FetchDescriptor<KotobaDataModel>()).first?.kanji, "森")
        }
        let reopened = try StudyStore(url: url)
        let repository = BackupRepository(store: reopened, catalog: catalog, recoveryURL: directory.appendingPathComponent("other.json"))
        let restored = try repository.validate(repository.export(preferences: .init()))
        XCTAssertEqual(restored.words, original.words)
        XCTAssertEqual(restored.kanjis, original.kanjis)
        XCTAssertEqual(restored.progress, original.progress)
    }

    func testExportRejectsMultipleProgressWithoutInventingOrCombiningCounters() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(progress())
        let second = progress(); second.id = "other"
        store.context.insert(second)
        try store.context.save()
        let repository = BackupRepository(store: store, catalog: CatalogSnapshot(words: [word()], kanjis: [kanji()]), recoveryURL: recoveryURL())
        XCTAssertThrowsError(try repository.export(preferences: .init()))
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).count, 2)
    }

    func testMissingProgressWithSavedContentRejectsBeforeRecoveryOrMutation() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(word()); store.context.insert(kanji()); store.context.insert(progress())
        try store.context.save()
        let recovery = recoveryURL()
        let repository = BackupRepository(store: store, catalog: CatalogSnapshot(words: [word()], kanjis: [kanji()]), recoveryURL: recovery)
        let original = try repository.validate(repository.export(preferences: .init()))
        var missing = original
        missing.progress = nil
        missing.kanjis = []
        XCTAssertThrowsError(try repository.restore(missing, currentPreferences: .init()))
        missing.words = []; missing.kanjis = original.kanjis
        XCTAssertThrowsError(try repository.restore(missing, currentPreferences: .init()))
        missing.words = original.words
        missing.reviews = [ReviewRecord(id: .init(kind: .word, id: "word"), stage: 0, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: nil, sessionHadAgain: false)]
        XCTAssertThrowsError(try repository.restore(missing, currentPreferences: .init()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recovery.path))
        let unchanged = try repository.validate(repository.export(preferences: .init()))
        XCTAssertEqual(unchanged.words, original.words)
        XCTAssertEqual(unchanged.kanjis, original.kanjis)
        XCTAssertEqual(unchanged.progress, original.progress)
    }

    private enum Failure: Error { case injected }
    private var date: Date { Date(timeIntervalSince1970: 1_700_000_000.125) }
    private func recoveryURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }
    private func word() -> KotobaDataModel { .init(id: "word", kanji: "森", furigana: "もり", english: [.init(value: "forest"), .init(value: "woods")], jlptLevel: .n5, dateAdded: date, addedIndex: nil) }
    private func kanji() -> KanjiDataModel { .init(id: "kanji", kanji: "森", stroke: 12, onyomi: [.init(value: "シン")], kunyomi: [.init(value: "もり")], jlptLevel: .n5, meanings: [.init(value: "forest")], dateAdded: nil, addedIndex: 0) }
    private func progress() -> WordsProgressModel { .init(id: "progress", kanjiProgress: 9, kotobaProgress: 7, kanjiLevel: .n4, kotobaLevel: .n5, kanjiIndex: 1, kotobaIndex: 0, lastKotobaUpdated: date, lastKanjiUpdated: date) }
}
