import XCTest
import SwiftData
@testable import DataKit

final class StudyFeaturesBackupTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_750_000_000)
    private enum Failure: Error { case injected }

    func testFormatThreeRoundTripPreservesListsOffGoalAndHistoricalActivity() throws {
        let store = try fixture()
        let list = StudyListModel(id: "travel", name: "Travel", createdAt: date)
        store.context.insert(list)
        store.context.insert(StudyListMembershipModel(listID: list.id, wordID: "word"))
        store.context.insert(DailyGoalSettingsModel(settings: .init(target: nil)))
        let history = PracticeActivity(id: .init(kind: .kanji, id: "deleted"), completedAt: date, calendar: Calendar(identifier: .gregorian))
        store.context.insert(PracticeActivityModel(activity: history))
        try store.context.save()
        let repo = repository(store)
        let original = try repo.validate(repo.export(preferences: .init()))
        XCTAssertEqual(original.formatVersion, 3)
        XCTAssertEqual(original.lists.map(\.name), ["Travel"])
        XCTAssertEqual(original.memberships.map(\.wordID), ["word"])
        XCTAssertNil(original.dailyGoal)
        XCTAssertEqual(original.activities, [history])
        let restoredStore = try StudyStore(inMemory: true)
        let restoredRepo = repository(restoredStore)
        try restoredRepo.restore(original, currentPreferences: .init())
        let restored = try restoredRepo.validate(restoredRepo.export(preferences: .init()))
        XCTAssertEqual(restored.lists, original.lists)
        XCTAssertEqual(restored.memberships, original.memberships)
        XCTAssertEqual(restored.activities, original.activities)
        XCTAssertEqual(restored.words, original.words)
        XCTAssertEqual(restored.progress, original.progress)
        XCTAssertNil(restored.dailyGoal)
    }

    func testOlderBackupMissingFieldsDefaultsAndIncompleteNewBackupRejects() throws {
        let store = try fixture()
        let repo = repository(store)
        let data = try repo.export(preferences: .init())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for field in ["lists", "memberships", "dailyGoal", "activities"] { json.removeValue(forKey: field) }
        json["formatVersion"] = 2
        let older = try repo.validate(JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(older.lists.isEmpty); XCTAssertTrue(older.activities.isEmpty)
        XCTAssertEqual(older.dailyGoal, 10)
        json["formatVersion"] = 3
        XCTAssertThrowsError(try repo.validate(JSONSerialization.data(withJSONObject: json)))
    }

    func testInvalidListMembershipGoalDayAndFutureVersionRejectBeforeRestore() throws {
        let store = try fixture()
        let repo = repository(store)
        let valid = try repo.validate(repo.export(preferences: .init()))
        var bad = valid
        bad.lists = [.init(id: "a", name: "Travel", createdAt: date), .init(id: "b", name: "ＴＲＡＶＥＬ", createdAt: date)]
        XCTAssertThrowsError(try repo.validate(bad))
        bad = valid; bad.memberships = [.init(listID: "missing", wordID: "word")]
        XCTAssertThrowsError(try repo.validate(bad))
        bad = valid; bad.dailyGoal = 7
        XCTAssertThrowsError(try repo.validate(bad))
        bad = valid; bad.activities = [.init(key: "bad", dayKey: "2026-02-31", studyID: .init(kind: .word, id: "word"), completedAt: date)]
        XCTAssertThrowsError(try repo.validate(bad))
        bad = valid; bad.formatVersion = 99
        XCTAssertThrowsError(try repo.restore(bad, currentPreferences: .init()))
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
    }

    func testRestoreFailureRollsBackListGoalAndActivityReplacement() throws {
        let store = try fixture()
        store.context.insert(StudyListModel(id: "old", name: "Old", createdAt: date))
        store.context.insert(DailyGoalSettingsModel(settings: .init(target: 20)))
        try store.context.save()
        let original = try repository(store).validate(repository(store).export(preferences: .init()))
        var changed = original
        changed.lists = [.init(id: "new", name: "New", createdAt: date)]
        changed.dailyGoal = nil
        let failing = BackupRepository(store: store, catalog: catalog(), recoveryURL: recovery(), save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failing.restore(changed, currentPreferences: .init()))
        let preserved = try repository(store).validate(repository(store).export(preferences: .init()))
        XCTAssertEqual(preserved.lists, original.lists)
        XCTAssertEqual(preserved.dailyGoal, original.dailyGoal)
        XCTAssertEqual(preserved.words, original.words)
    }

    func testWordDeletionRemovesMembershipButRetainsCompletedActivity() throws {
        let store = try fixture()
        store.context.insert(StudyListModel(id: "list", name: "List", createdAt: date))
        store.context.insert(StudyListMembershipModel(listID: "list", wordID: "word"))
        store.context.insert(PracticeActivityModel(activity: .init(id: .init(kind: .word, id: "word"), completedAt: date, calendar: .current)))
        try store.context.save()
        _ = try StandardStudyMutationRepository(store: store, catalogLevel: { _ in "N5" }).delete(id: .init(kind: .word, id: "word"))
        XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<StudyListMembershipModel>()).isEmpty)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<PracticeActivityModel>()).count, 1)
    }

    func testOldFourModelDiskStoreUpgradePreservesStudyAndAdvice() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("old.store")
        do {
            let schema = Schema([KotobaDataModel.self, KanjiDataModel.self, WordsProgressModel.self, ReviewRecordModel.self])
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            context.insert(word()); let counters = progress(); counters.kanjiProgress = 1; counters.kanjiIndex = 1; context.insert(counters)
            context.insert(KanjiDataModel(id: "kanji", kanji: "森", stroke: 12, onyomi: [.init(value: "シン")], kunyomi: [.init(value: "もり")], jlptLevel: .n5, meanings: [.init(value: "forest")], dateAdded: date, addedIndex: 0))
            context.insert(ReviewRecordModel(record: .init(id: .init(kind: .word, id: "word"), stage: 2, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, sessionBaselineStage: 1, sessionHadAgain: false)))
            try context.save()
        }
        let reopened = try StudyStore(url: url)
        let saved = try XCTUnwrap(reopened.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).first)
        XCTAssertEqual(saved.id, "word"); XCTAssertEqual(saved.memoryMnemonic, "A forest memory")
        XCTAssertEqual(saved.english.map(\.value), ["forest"])
        XCTAssertEqual(try reopened.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaIndex, 1)
        let kanji = try XCTUnwrap(reopened.makeContext().fetch(FetchDescriptor<KanjiDataModel>()).first)
        XCTAssertEqual(kanji.id, "kanji"); XCTAssertEqual(kanji.kunyomi.map(\.value), ["もり"])
        XCTAssertEqual(kanji.addedIndex, 0); XCTAssertEqual(kanji.dateAdded, date)
        let review = try XCTUnwrap(reopened.makeContext().fetch(FetchDescriptor<ReviewRecordModel>()).first)
        XCTAssertEqual(review.stage, 2); XCTAssertEqual(review.dueDate, date)
        XCTAssertEqual(review.sessionBaselineStage, 1); XCTAssertFalse(review.sessionHadAgain)
        XCTAssertTrue(try reopened.makeContext().fetch(FetchDescriptor<StudyListModel>()).isEmpty)
        let snapshot = CatalogSnapshot(words: [word()], kanjis: [kanji], version: 2)
        let backup = BackupRepository(store: reopened, catalog: snapshot, recoveryURL: recovery())
        let before = try backup.validate(backup.export(preferences: .init()))
        let lists = StandardStudyListRepository(store: reopened, makeID: { "travel" }, now: { self.date })
        let list = try lists.create(name: "Travel")
        try lists.setLists(wordID: "word", listIDs: [list.id])
        let goals = StandardDailyGoalRepository(store: reopened)
        try goals.record(.init(id: .init(kind: .word, id: "word"), completedAt: date))
        let due = ReviewRecord(id: .init(kind: .kanji, id: "kanji"), stage: 1, dueDate: date.addingTimeInterval(86400), lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: 0, sessionHadAgain: false)
        try StandardReviewRepository(store: reopened).save(due, activity: .init(id: due.id, completedAt: date))
        let after = try backup.validate(backup.export(preferences: .init()))
        XCTAssertEqual(after.words, before.words)
        XCTAssertEqual(after.kanjis, before.kanjis)
        XCTAssertEqual(after.progress, before.progress)
        XCTAssertEqual(after.reviews.first { $0.id.kind == .word }, before.reviews.first)
        XCTAssertEqual(after.activities.count, 2)
        let restoredURL = folder.appendingPathComponent("restored.store")
        do {
            let restoredStore = try StudyStore(url: restoredURL)
            let restore = BackupRepository(store: restoredStore, catalog: snapshot, recoveryURL: recovery())
            try restore.restore(after, currentPreferences: .init())
        }
        let restoredStore = try StudyStore(url: restoredURL)
        let restore = BackupRepository(store: restoredStore, catalog: snapshot, recoveryURL: recovery())
        let final = try restore.validate(restore.export(preferences: .init()))
        XCTAssertEqual(final.words, after.words); XCTAssertEqual(final.kanjis, after.kanjis)
        XCTAssertEqual(final.progress, after.progress); XCTAssertEqual(final.reviews, after.reviews)
        XCTAssertEqual(final.lists, after.lists); XCTAssertEqual(final.memberships, after.memberships)
        XCTAssertEqual(final.activities, after.activities); XCTAssertEqual(final.dailyGoal, after.dailyGoal)

    }

    private func fixture() throws -> StudyStore {
        let store = try StudyStore(inMemory: true)
        store.context.insert(word()); store.context.insert(progress()); try store.context.save()
        return store
    }
    private func word() -> KotobaDataModel {
        .init(id: "word", kanji: "森", furigana: "もり", english: [.init(value: "forest")], jlptLevel: .n5, dateAdded: date, addedIndex: 0,
              memoryExplanation: "A forest", memoryMnemonic: "A forest memory", catalogID: "forest")
    }
    private func progress() -> WordsProgressModel {
        .init(id: "progress", kanjiProgress: 0, kotobaProgress: 1, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 1, lastKotobaUpdated: date, lastKanjiUpdated: date, catalogVersion: 2)
    }
    private func catalog() -> CatalogSnapshot { .init(words: [word()], kanjis: [], version: 2) }
    private func recovery() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json") }
    private func repository(_ store: StudyStore) -> BackupRepository { .init(store: store, catalog: catalog(), recoveryURL: recovery()) }
}
