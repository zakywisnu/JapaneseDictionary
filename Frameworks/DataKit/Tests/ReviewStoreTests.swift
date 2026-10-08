import XCTest
import SwiftData
@testable import DataKit

final class ReviewStoreTests: XCTestCase {
    func testExistingDiskStoreKeepsAllFieldsWhenReviewSchemaIsAdded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("JapaneseDictionary.store")
        try seedLegacyStore(url: url)
        let store = try StudyStore(url: url)
        let word = try XCTUnwrap(store.context.fetch(FetchDescriptor<KotobaDataModel>()).first)
        XCTAssertEqual(word.id, "shared")
        XCTAssertEqual(word.kanji, "森")
        XCTAssertEqual(word.furigana, "もり")
        XCTAssertEqual(word.english.map(\.value), ["forest", "woods"])
        XCTAssertEqual(word.jlptLevel, .n4)
        XCTAssertEqual(word.dateAdded, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(word.addedIndex, 17)
        let kanji = try XCTUnwrap(store.context.fetch(FetchDescriptor<KanjiDataModel>()).first)
        XCTAssertEqual(kanji.id, "shared")
        XCTAssertEqual(kanji.kanji, "木")
        XCTAssertEqual(kanji.stroke, 4)
        XCTAssertEqual(kanji.onyomi.map(\.value), ["モク", "ボク"])
        XCTAssertEqual(kanji.kunyomi.map(\.value), ["き"])
        XCTAssertEqual(kanji.meanings.map(\.value), ["tree", "wood"])
        XCTAssertEqual(kanji.jlptLevel, .n5)
        XCTAssertNil(kanji.dateAdded)
        XCTAssertNil(kanji.addedIndex)
        let progress = try XCTUnwrap(store.context.fetch(FetchDescriptor<WordsProgressModel>()).first)
        XCTAssertEqual(progress.id, "progress")
        XCTAssertEqual(progress.kanjiProgress, 13)
        XCTAssertEqual(progress.kotobaProgress, 41)
        XCTAssertEqual(progress.kanjiLevel, .n4)
        XCTAssertEqual(progress.kotobaLevel, .n3)
        XCTAssertEqual(progress.kanjiIndex, 12)
        XCTAssertEqual(progress.kotobaIndex, 40)
        XCTAssertEqual(progress.lastKotobaUpdated, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(progress.lastKanjiUpdated, Date(timeIntervalSince1970: 3_000))
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<ReviewRecordModel>()).isEmpty)
    }

    func testFailedRecordSaveRollsBackExistingAndInsertedRecords() throws {
        let store = try populatedStore()
        let id = SavedStudyID(kind: .word, id: "shared")
        let good = StandardReviewRepository(context: store.context)
        let original = record(id: id, stage: 2)
        try good.save(original)
        let failing = StandardReviewRepository(context: store.context, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failing.save(record(id: id, stage: 3)))
        XCTAssertEqual(try good.records(), [original])
        XCTAssertThrowsError(try failing.save(record(id: .init(kind: .kanji, id: "shared"), stage: 1)))
        XCTAssertEqual(try good.records(), [original])
    }

    func testDeleteSavesItemScheduleAndCumulativeProgressTogether() throws {
        let store = try populatedStore()
        let review = StandardReviewRepository(context: store.context)
        try review.save(record(id: .init(kind: .word, id: "shared"), stage: 2))
        try review.save(record(id: .init(kind: .kanji, id: "shared"), stage: 1))
        let mutations = StandardStudyMutationRepository(context: store.context)
        let result = try mutations.delete(id: .init(kind: .word, id: "shared"))
        XCTAssertEqual(result.kotobaProgress, 40)
        XCTAssertEqual(result.kotobaIndex, 17)
        XCTAssertEqual(result.kotobaLevel, "N4")
        XCTAssertEqual(result.kanjiProgress, 13)
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<KotobaDataModel>()).isEmpty)
        XCTAssertEqual(try review.records().map(\.id), [.init(kind: .kanji, id: "shared")])
    }

    func testFailedDeleteKeepsItemScheduleAndProgress() throws {
        let store = try populatedStore()
        let review = StandardReviewRepository(context: store.context)
        let original = record(id: .init(kind: .word, id: "shared"), stage: 2)
        try review.save(original)
        let mutations = StandardStudyMutationRepository(context: store.context, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try mutations.delete(id: original.id))
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
        XCTAssertEqual(try review.records(), [original])
        let progress = try XCTUnwrap(store.context.fetch(FetchDescriptor<WordsProgressModel>()).first)
        XCTAssertEqual(progress.kotobaProgress, 41)
        XCTAssertEqual(progress.kotobaIndex, 40)
        XCTAssertEqual(progress.kotobaLevel, .n3)
    }

    func testUnknownSavedItemCannotGainSchedule() throws {
        let store = try populatedStore()
        let repo = StandardReviewRepository(context: store.context)
        XCTAssertThrowsError(try repo.save(record(id: .init(kind: .word, id: "missing"), stage: 0)))
        XCTAssertTrue(try repo.records().isEmpty)
    }

    func testAtomicReviewFailureRollsBackScheduleAndActivity() throws {
        let store = try populatedStore()
        let id = SavedStudyID(kind: .word, id: "shared")
        let good = StandardReviewRepository(store: store)
        let original = record(id: id, stage: 2)
        try good.save(original)
        let activity = PracticeActivity(id: id, completedAt: original.lastReviewedAt)
        let failing = StandardReviewRepository(store: store, save: { context in
            XCTAssertEqual(try context.fetch(FetchDescriptor<PracticeActivityModel>()).count, 1)
            throw Failure.injected
        })
        XCTAssertThrowsError(try failing.save(record(id: id, stage: 3), activity: activity))
        XCTAssertEqual(try good.records(), [original])
        XCTAssertTrue(try StandardDailyGoalRepository(store: store).activities(dayKey: activity.dayKey).isEmpty)
        try good.save(record(id: id, stage: 3), activity: activity)
        XCTAssertEqual(try good.records().first?.stage, 3)
        XCTAssertEqual(try StandardDailyGoalRepository(store: store).activities(dayKey: activity.dayKey), [activity])
    }

    private func populatedStore() throws -> StudyStore {
        let store = try StudyStore(inMemory: true)
        seed(context: store.context)
        try store.context.save()
        return store
    }

    private func seedLegacyStore(url: URL) throws {
        let schema = Schema([KanjiDataModel.self, KotobaDataModel.self, WordsProgressModel.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        seed(context: context)
        try context.save()
    }

    private func seed(context: ModelContext) {
        context.insert(KotobaDataModel(id: "shared", kanji: "森", furigana: "もり", english: ["forest", "woods"].map(ArrayString.init), jlptLevel: .n4, dateAdded: Date(timeIntervalSince1970: 1_000), addedIndex: 17))
        context.insert(KanjiDataModel(id: "shared", kanji: "木", stroke: 4, onyomi: ["モク", "ボク"].map(ArrayString.init), kunyomi: [ArrayString(value: "き")], jlptLevel: .n5, meanings: ["tree", "wood"].map(ArrayString.init), dateAdded: nil, addedIndex: nil))
        context.insert(WordsProgressModel(id: "progress", kanjiProgress: 13, kotobaProgress: 41, kanjiLevel: .n4, kotobaLevel: .n3, kanjiIndex: 12, kotobaIndex: 40, lastKotobaUpdated: Date(timeIntervalSince1970: 2_000), lastKanjiUpdated: Date(timeIntervalSince1970: 3_000)))
    }

    private func record(id: SavedStudyID, stage: Int) -> ReviewRecord {
        ReviewRecord(id: id, stage: stage, dueDate: Date(timeIntervalSince1970: 8_000), lastReviewedAt: Date(timeIntervalSince1970: 5_000), lastSessionID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, sessionBaselineStage: 1, sessionHadAgain: false)
    }
    private enum Failure: Error { case injected }
}
