import XCTest
import SwiftData
@testable import DataKit

final class CatalogMigrationTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_750_000_000)
    private enum Failure: Error { case injected }

    func testMigrationPreservesStudyAndAdviceOffersNewWordAndIsIdempotent() throws {
        let store = try StudyStore(inMemory: true)
        let saved = word(id: "learner", headword: "青", reading: "あお", index: 0)
        saved.memoryExplanation = "blue"; saved.memoryMnemonic = "sky"
        store.context.insert(saved); store.context.insert(progress(index: 2))
        let review = ReviewRecord(id: .init(kind: .word, id: "learner"), stage: 2, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: nil, sessionHadAgain: false)
        store.context.insert(ReviewRecordModel(record: review)); try store.context.save()
        let migration = try makeMigration(store)
        try migration.ensureCurrent()
        let after = try XCTUnwrap(store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first)
        XCTAssertEqual(after.id, "learner"); XCTAssertEqual(after.english.map(\.value), ["blue"])
        XCTAssertEqual(after.dateAdded, date); XCTAssertEqual(after.memoryMnemonic, "sky")
        XCTAssertEqual(after.catalogID, "blue"); XCTAssertEqual(after.addedIndex, 1)
        let next = try XCTUnwrap(store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first)
        XCTAssertEqual(next.catalogVersion, 2); XCTAssertEqual(next.kotobaIndex, 0)
        XCTAssertEqual(next.kotobaProgress, 8); XCTAssertEqual(next.lastKotobaUpdated, date)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<ReviewRecordModel>()).first?.value, review)
        next.kotobaIndex = 2; try next.modelContext?.save()
        try migration.ensureCurrent()
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaIndex, 2)
    }

    func testRecoveryAndSaveFailureLeaveOriginalStoreUntouched() throws {
        for recoveryFails in [true, false] {
            let store = try StudyStore(inMemory: true)
            store.context.insert(word(id: "learner", headword: "青", reading: "あお", index: 0))
            store.context.insert(progress(index: 2)); try store.context.save()
            var saved = false
            let migration = try makeMigration(store, save: { _ in saved = true; throw Failure.injected },
                writeRecovery: { _, _ in if recoveryFails { throw Failure.injected } })
            XCTAssertThrowsError(try migration.ensureCurrent())
            XCTAssertEqual(saved, !recoveryFails)
            let next = try XCTUnwrap(store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first)
            XCTAssertNil(next.catalogVersion); XCTAssertEqual(next.kotobaIndex, 2)
            XCTAssertNil(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first?.catalogID)
        }
    }

    func testLegacyBackupConversionValidatesBeforeMappingAndKeepsRetiredContent() throws {
        let store = try StudyStore(inMemory: true)
        let migration = try makeMigration(store)
        let oldWords = legacyWords()
        let oldCatalog = CatalogSnapshot(words: oldWords, kanjis: [])
        var backup = StudyBackup(createdAt: date, catalogFingerprint: oldCatalog.fingerprint,
            words: [BackupWord(oldWords[0]), BackupWord(oldWords[1])], kanjis: [],
            progress: BackupProgress(progress(index: 2)), reviews: [], preferences: .init())
        let converted = try migration.prepareLegacyBackup(backup)
        XCTAssertEqual(converted.formatVersion, 2)
        XCTAssertEqual(converted.words[1].kanji, "旧語")
        XCTAssertNil(converted.words[1].catalogID); XCTAssertNil(converted.words[1].addedIndex)
        XCTAssertEqual(converted.progress?.catalogVersion, 2)
        backup.catalogFingerprint = "foreign"
        XCTAssertThrowsError(try migration.prepareLegacyBackup(backup))
        backup.catalogFingerprint = oldCatalog.fingerprint
        backup.progress?.kotobaIndex = 3
        XCTAssertThrowsError(try migration.prepareLegacyBackup(backup))
    }

    func testStaleStudyUpdatePreservesMigratedAnchorAndClearsOnlyAdvice() throws {
        let store = try StudyStore(inMemory: true)
        let saved = word(id: "learner", headword: "青", reading: "あお", index: 0)
        saved.memoryExplanation = "blue"; saved.memoryMnemonic = "sky"
        store.context.insert(saved); store.context.insert(progress(index: 2)); try store.context.save()
        let migration = try makeMigration(store)
        let repository = StandardKotobaRepository(store: store, prepare: migration.ensureCurrent)
        let stale = word(id: "learner", headword: "青", reading: "あお", index: 0)
        stale.english = [.init(value: "blue colour")]
        try repository.update(stale)
        let updated = try repository.fetch(id: "learner")
        XCTAssertEqual(updated.catalogID, "blue"); XCTAssertEqual(updated.addedIndex, 1)
        XCTAssertEqual(updated.dateAdded, date); XCTAssertNil(updated.memoryMnemonic)
        XCTAssertEqual(updated.english.map(\.value), ["blue colour"])
        XCTAssertNoThrow(try BackupRepository(store: store, catalog: migration.currentSnapshot,
            recoveryURL: URL(fileURLWithPath: "/tmp/unused")).export(preferences: .init()))
    }

    func testCollectionReadsPrepareMigration() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(word(id: "learner", headword: "青", reading: "あお", index: 0))
        store.context.insert(progress(index: 2)); try store.context.save()
        let migration = try makeMigration(store)
        XCTAssertEqual(try StandardKotobaRepository(store: store, prepare: migration.ensureCurrent).fetchAll().first?.catalogID, "blue")
    }

    func testDeleteCurrentAnchorUsesCurrentLevelAndRetiredWordKeepsCursor() throws {
        for retired in [false, true] {
            let store = try StudyStore(inMemory: true)
            let saved = word(id: "learner", headword: "青", reading: "あお", index: 0)
            saved.jlptLevel = .n4; saved.catalogID = retired ? nil : "blue"; saved.addedIndex = retired ? nil : 1
            let next = progress(index: 2); next.catalogVersion = 2; next.kotobaLevel = .n3
            store.context.insert(saved); store.context.insert(next); try store.context.save()
            let result = try StandardStudyMutationRepository(store: store, catalogLevel: { _ in "N5" }).delete(id: .init(kind: .word, id: "learner"))
            XCTAssertEqual(result.kotobaIndex, retired ? 2 : 1)
            XCTAssertEqual(result.kotobaLevel, retired ? "N3" : "N5")
        }
    }

    func testFailedStudyUpdateRollsBackMeaningsAndAdvice() throws {
        let store = try StudyStore(inMemory: true)
        let saved = word(id: "learner", headword: "青", reading: "あお", index: 1)
        saved.catalogID = "blue"; saved.memoryExplanation = "blue"; saved.memoryMnemonic = "sky"
        store.context.insert(saved); try store.context.save()
        let changed = word(id: "learner", headword: "青", reading: "あお", index: 1)
        changed.english = [.init(value: "blue colour")]
        let repository = StandardKotobaRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try repository.update(changed))
        let unchanged = try repository.fetch(id: "learner")
        XCTAssertEqual(unchanged.english.map(\.value), ["blue"])
        XCTAssertEqual(unchanged.memoryMnemonic, "sky"); XCTAssertEqual(unchanged.catalogID, "blue")
    }

    func testLegacyRestoreExportsValidCurrentBackupAndRestartKeepsCursor() throws {
        let store = try StudyStore(inMemory: true)
        let migration = try makeMigration(store)
        let backup = StudyBackup(createdAt: date, catalogFingerprint: migration.legacySnapshot.fingerprint,
            words: [BackupWord(legacyWords()[0])], kanjis: [], progress: BackupProgress(progress(index: 2)),
            reviews: [], preferences: .init(todayKind: .kanji))
        let repository = BackupRepository(store: store, catalog: migration.currentSnapshot,
            recoveryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            prepare: migration.ensureCurrent, legacyConverter: migration.prepareLegacyBackup)
        let preview = try repository.validate(JSONEncoder().encode(backup))
        XCTAssertEqual(preview.progress?.kotobaIndex, 0)
        try repository.restore(backup, currentPreferences: .init())
        try migration.ensureCurrent()
        let exported = try repository.validate(repository.export(preferences: preview.preferences))
        XCTAssertEqual(exported.words, preview.words)
        XCTAssertEqual(exported.progress, preview.progress)
        XCTAssertEqual(exported.formatVersion, 6)
    }

    func testFutureCatalogVersionCannotMutateSavedAnchors() throws {
        let store = try StudyStore(inMemory: true)
        let saved = word(id: "learner", headword: "青", reading: "あお", index: 0)
        let next = progress(index: 2); next.catalogVersion = 99
        store.context.insert(saved); store.context.insert(next); try store.context.save()
        XCTAssertThrowsError(try makeMigration(store).ensureCurrent())
        XCTAssertNil(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first?.catalogID)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.catalogVersion, 99)
    }

    private func makeMigration(_ store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() },
        writeRecovery: @escaping (Data, URL) throws -> Void = { _, _ in }) throws -> CatalogMigration {
        let entries = [entry(id: "new", headword: "赤", reading: "あか", meaning: "red"),
                       entry(id: "blue", headword: "青", reading: "あお", meaning: "blue")]
        let catalog = try VocabularyCatalogRepository(catalog: .init(version: 2, created: "2026-10-07", jmdictCreated: "2026-10-07", entries: entries, legacyMap: ["blue", nil]))
        return CatalogMigration(store: store, vocabulary: catalog, legacyWords: legacyWords(), kanjis: [],
            recoveryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            save: save, writeRecovery: writeRecovery)
    }
    private func entry(id: String, headword: String, reading: String, meaning: String) -> DictionaryWord {
        .init(id: id, jmdictID: id == "blue" ? 1381380 : 2013900, headword: headword, reading: reading, level: "N5",
              studyMeanings: [meaning], forms: [.init(text: headword, notes: [], common: false)],
              readings: [.init(text: reading, spellings: [headword], notes: [], common: false, kanaOnly: false)],
              senses: [.init(meanings: [meaning], pos: ["noun"], labels: [], notes: [], spellings: [], readings: [])])
    }
    private func legacyWords() -> [KotobaDataModel] {
        [word(id: "old-blue", headword: "青", reading: "あお", index: 0),
         word(id: "old-retired", headword: "旧語", reading: "きゅうご", index: 1)]
    }
    private func word(id: String, headword: String, reading: String, index: Int) -> KotobaDataModel {
        .init(id: id, kanji: headword, furigana: reading, english: [.init(value: headword == "青" ? "blue" : "retired")],
              jlptLevel: .n5, dateAdded: date, addedIndex: index)
    }
    private func progress(index: Int) -> WordsProgressModel {
        .init(id: "progress", kanjiProgress: 2, kotobaProgress: 8, kanjiLevel: .n5, kotobaLevel: .n5,
              kanjiIndex: 0, kotobaIndex: index, lastKotobaUpdated: date, lastKanjiUpdated: date)
    }
}
