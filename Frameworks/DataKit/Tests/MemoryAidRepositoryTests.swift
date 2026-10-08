import XCTest
import SwiftData
import CryptoKit
@testable import DataKit

final class MemoryAidRepositoryTests: XCTestCase {
    func testValidationTrimsAndRejectsEmptyOrLongFields() throws {
        XCTAssertEqual(try MemoryAidSuggestion(explanation: " forest \n", mnemonic: " trees ").validated(), suggestion)
        for invalid in [MemoryAidSuggestion(explanation: " ", mnemonic: "trees"), .init(explanation: "forest", mnemonic: String(repeating: "x", count: 601))] {
            XCTAssertThrowsError(try invalid.validated())
        }
    }

    func testSaveReloadPreservesDictionaryProgressAndSchedule() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("memory.store")
        var original: StudyBackup!
        do {
            let store = try StudyStore(url: url)
            try seed(store)
            let backup = backupRepository(store)
            original = try backup.validate(backup.export(preferences: .init()))
            try StandardMemoryAidRepository(store: store).save(suggestion, for: input)
            XCTAssertEqual(try StandardMemoryAidRepository(store: store).load(for: input), suggestion)
        }
        let reopened = try StudyStore(url: url)
        XCTAssertEqual(try StandardMemoryAidRepository(store: reopened).load(for: input), suggestion)
        let backup = backupRepository(reopened)
        var after = try backup.validate(backup.export(preferences: .init()))
        XCTAssertEqual(after.words[0].memoryAid, suggestion)
        after.words[0].memoryAid = nil
        XCTAssertEqual(after.words, original.words)
        XCTAssertEqual(after.progress, original.progress)
        XCTAssertEqual(after.reviews, original.reviews)
    }

    func testFailedSaveLeavesSavedAdviceAndOtherContextChangesUntouched() throws {
        let store = try StudyStore(inMemory: true)
        try seed(store)
        try StandardMemoryAidRepository(store: store).save(suggestion, for: input)
        let word = try XCTUnwrap(store.context.fetch(FetchDescriptor<KotobaDataModel>()).first)
        word.dateAdded = date.addingTimeInterval(1)
        let repository = StandardMemoryAidRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try repository.save(.init(explanation: "replacement", mnemonic: "replacement"), for: input))
        XCTAssertEqual(word.dateAdded, date.addingTimeInterval(1))
        XCTAssertEqual(try StandardMemoryAidRepository(store: store).load(for: input), suggestion)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first?.dateAdded, date)
    }

    func testMissingChangedAndPartialSavedWordsReject() throws {
        let store = try StudyStore(inMemory: true)
        let repository = StandardMemoryAidRepository(store: store)
        XCTAssertThrowsError(try repository.save(suggestion, for: input)) { XCTAssertEqual($0 as? MemoryAidStorageError, .missingWord) }
        try seed(store)
        let word = try XCTUnwrap(store.context.fetch(FetchDescriptor<KotobaDataModel>()).first)
        word.furigana = "changed"
        try store.context.save()
        XCTAssertThrowsError(try repository.save(suggestion, for: input)) { XCTAssertEqual($0 as? MemoryAidStorageError, .changedWord) }
        word.furigana = input.reading
        word.memoryExplanation = "partial"
        try store.context.save()
        XCTAssertThrowsError(try repository.load(for: input)) { XCTAssertEqual($0 as? MemoryAidStorageError, .invalidSuggestion) }
        XCTAssertThrowsError(try backupRepository(store).export(preferences: .init()))
    }

    func testEveryChangedDictionaryFieldRejectsAdviceAndDeletionRejectsLateSave() throws {
        let store = try StudyStore(inMemory: true)
        try seed(store)
        let repository = StandardMemoryAidRepository(store: store)
        XCTAssertNil(try repository.load(for: input))
        let changedInputs: [MemoryAidWord] = [
            .init(id: input.id, headword: "林", reading: input.reading, meanings: input.meanings, level: input.level),
            .init(id: input.id, headword: input.headword, reading: "りん", meanings: input.meanings, level: input.level),
            .init(id: input.id, headword: input.headword, reading: input.reading, meanings: ["woods"], level: input.level),
            .init(id: input.id, headword: input.headword, reading: input.reading, meanings: input.meanings, level: "N4")
        ]
        for changed in changedInputs {
            XCTAssertThrowsError(try repository.save(suggestion, for: changed)) { XCTAssertEqual($0 as? MemoryAidStorageError, .changedWord) }
        }
        XCTAssertNil(try repository.load(for: input))
        try StandardKotobaRepository(store: store).delete(id: input.id)
        XCTAssertThrowsError(try repository.save(suggestion, for: input)) { XCTAssertEqual($0 as? MemoryAidStorageError, .missingWord) }
    }

    func testBackupPreservesAdviceRejectsMalformedAndRollsBack() throws {
        let store = try StudyStore(inMemory: true)
        try seed(store)
        try StandardMemoryAidRepository(store: store).save(suggestion, for: input)
        let repository = backupRepository(store)
        let original = try repository.validate(repository.export(preferences: .init()))
        XCTAssertEqual(original.words[0].memoryAid, suggestion)
        var changed = original
        changed.words[0].memoryAid = .init(explanation: "changed", mnemonic: "changed")
        let failing = BackupRepository(store: store, catalog: catalog, recoveryURL: recoveryURL(), save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failing.restore(changed, currentPreferences: .init()))
        XCTAssertEqual(try StandardMemoryAidRepository(store: store).load(for: input), suggestion)
        try repository.restore(changed, currentPreferences: .init())
        XCTAssertEqual(try StandardMemoryAidRepository(store: store).load(for: input), changed.words[0].memoryAid)
        changed.words[0].memoryAid = .init(explanation: "", mnemonic: "valid")
        XCTAssertThrowsError(try repository.restore(changed, currentPreferences: .init()))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var words = try XCTUnwrap(json["words"] as? [[String: Any]])
        words[0]["memoryAid"] = ["explanation": "partial"]
        json["words"] = words
        XCTAssertThrowsError(try repository.validate(JSONSerialization.data(withJSONObject: json)))
    }

    func testLegacyBackupAndSemanticFingerprintRemainCompatible() throws {
        let store = try StudyStore(inMemory: true)
        try seed(store)
        let repository = backupRepository(store)
        let data = try repository.export(preferences: .init())
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("memoryAid"))
        XCTAssertNil(try repository.validate(data).words[0].memoryAid)
        let model = word()
        let withoutAdvice = CatalogSnapshot(words: [model], kanjis: []).fingerprint
        model.memoryExplanation = suggestion.explanation
        model.memoryMnemonic = suggestion.mnemonic
        XCTAssertEqual(CatalogSnapshot(words: [model], kanjis: []).fingerprint, withoutAdvice)
        let legacy: [String: Any] = ["words": [["id": "", "kanji": "森", "furigana": "もり", "english": ["forest"], "jlptLevel": "N5"]], "kanjis": []]
        let bytes = try JSONSerialization.data(withJSONObject: legacy, options: .sortedKeys)
        importFingerprint(bytes, expected: withoutAdvice)
    }

    func testDictionaryUpdateInvalidatesAdvice() throws {
        let store = try StudyStore(inMemory: true)
        try seed(store)
        try StandardMemoryAidRepository(store: store).save(suggestion, for: input)
        let replacement = word()
        replacement.english = [.init(value: "woods")]
        try StandardKotobaRepository(store: store).update(replacement)
        let saved = try XCTUnwrap(store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first)
        XCTAssertNil(saved.memoryExplanation)
        XCTAssertNil(saved.memoryMnemonic)
    }

    private enum Failure: Error { case injected }
    private var date: Date { Date(timeIntervalSince1970: 1_700_000_000) }
    private var input: MemoryAidWord { .init(id: "word", headword: "森", reading: "もり", meanings: ["forest"], level: "N5") }
    private var suggestion: MemoryAidSuggestion { .init(explanation: "forest", mnemonic: "trees") }
    private var catalog: CatalogSnapshot { .init(words: [word()], kanjis: []) }
    private func word() -> KotobaDataModel { .init(id: "word", kanji: "森", furigana: "もり", english: [.init(value: "forest")], jlptLevel: .n5, dateAdded: date, addedIndex: 0) }
    private func recoveryURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }
    private func backupRepository(_ store: StudyStore) -> BackupRepository { .init(store: store, catalog: catalog, recoveryURL: recoveryURL()) }
    private func seed(_ store: StudyStore) throws {
        store.context.insert(word())
        store.context.insert(WordsProgressModel(id: "progress", kanjiProgress: 0, kotobaProgress: 1, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 1, lastKotobaUpdated: date, lastKanjiUpdated: date))
        store.context.insert(ReviewRecordModel(record: .init(id: .init(kind: .word, id: "word"), stage: 2, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: 1, sessionHadAgain: false)))
        try store.context.save()
    }
}

private func importFingerprint(_ data: Data, expected: String) {
    XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), expected)
}
