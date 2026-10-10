import XCTest
import SwiftData
@testable import DataKit

final class StudyRatingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)
    private func card() -> StudyMaterial {
        StudyMaterial(id: UUID().uuidString, kind: .customCard, prompt: "森", answer: "Forest", createdAt: now, updatedAt: now)
    }
    func testSessionRecoveryAndActionRetries() throws {
        let store = try StudyStore(inMemory: true)
        let material = try StandardStudyMaterialRepository(store: store).save(card())
        let id = SavedStudyID(kind: material.kind, id: material.id)
        let repository = StandardStudyRatingRepository(store: store)
        let session = UUID(), action = UUID()
        try repository.record(id: id, sessionID: session, actionID: action, again: true, now: now, review: nil, activity: nil)
        try repository.record(id: id, sessionID: session, actionID: action, again: true, now: now, review: nil, activity: nil)
        XCTAssertEqual(try repository.records().first?.missCount, 1)
        try repository.record(id: id, sessionID: session, actionID: UUID(), again: false, now: now, review: nil, activity: nil)
        XCTAssertEqual(try repository.records().first?.missCount, 1)
        try repository.record(id: id, sessionID: UUID(), actionID: UUID(), again: false, now: now, review: nil, activity: nil)
        XCTAssertEqual(try repository.records().first?.missCount, 0)
    }
    func testFailedRatingRollsBackAllEffectsAndMissingItemRejected() throws {
        let store = try StudyStore(inMemory: true)
        let material = try StandardStudyMaterialRepository(store: store).save(card())
        let id = SavedStudyID(kind: material.kind, id: material.id)
        let repository = StandardStudyRatingRepository(store: store, save: { _ in throw Failure.injected })
        let session = UUID()
        let review = ReviewRecord(id: id, stage: 1, dueDate: now, lastReviewedAt: now, lastSessionID: session, sessionBaselineStage: nil, sessionHadAgain: false)
        XCTAssertThrowsError(try repository.record(id: id, sessionID: session, actionID: UUID(), again: false, now: now, review: review, activity: PracticeActivity(id: id, completedAt: now)))
        XCTAssertTrue(try repository.records().isEmpty)
        XCTAssertTrue(try StandardReviewRepository(store: store).records().isEmpty)
        XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<PracticeActivityModel>()).isEmpty)
        try StandardStudyMaterialRepository(store: store).delete(id)
        XCTAssertThrowsError(try StandardStudyRatingRepository(store: store).record(id: id, sessionID: UUID(), actionID: UUID(), again: true, now: now, review: nil, activity: nil))
    }
    func testMeaningfulEditResetsButNotesRetainDifficulty() throws {
        let store = try StudyStore(inMemory: true)
        let materials = StandardStudyMaterialRepository(store: store)
        var material = try materials.save(card())
        let id = SavedStudyID(kind: material.kind, id: material.id)
        let ratings = StandardStudyRatingRepository(store: store)
        try ratings.record(id: id, sessionID: UUID(), actionID: UUID(), again: true, now: now, review: nil, activity: nil)
        material.notes = "A tree"
        _ = try materials.save(material)
        XCTAssertEqual(try ratings.records().first?.missCount, 1)
        material.answer = "Woods"
        _ = try materials.save(material)
        XCTAssertTrue(try ratings.records().isEmpty)
    }
    func testBundledSourceDeduplicatesAndKeepsSavedUUID() throws {
        let store = try StudyStore(inMemory: true)
        let repository = StandardStudyMaterialRepository(store: store, now: { self.now })
        let lesson = try XCTUnwrap(LessonCatalogRepository().materials().first)
        let first = try repository.save(lesson)
        let repeated = try repository.save(lesson)
        XCTAssertNotNil(UUID(uuidString: first.id))
        XCTAssertEqual(first.id, repeated.id)
        XCTAssertEqual(first.createdAt, now)
        XCTAssertEqual(repeated.createdAt, first.createdAt)
        XCTAssertEqual(first.source?.snapshot, lesson.source?.snapshot)
        XCTAssertEqual(try repository.materials().count, 1)
    }
    func testCorruptMaterialPayloadThrowsInsteadOfCrashing() throws {
        let store = try StudyStore(inMemory: true)
        let context = store.makeContext()
        let model = try StudyMaterialModel(value: card())
        model.payload = Data("broken".utf8)
        context.insert(model)
        try context.save()
        XCTAssertThrowsError(try StandardStudyMaterialRepository(store: store).materials())
        XCTAssertThrowsError(try StandardReviewRepository(store: store).savedItems(kind: .customCard))
    }
    func testMaterialAndDifficultySurviveDiskReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("study.store")
        let id: SavedStudyID
        do {
            let store = try StudyStore(url: url)
            let saved = try StandardStudyMaterialRepository(store: store).save(card())
            id = SavedStudyID(kind: saved.kind, id: saved.id)
            try StandardStudyRatingRepository(store: store).record(id: id, sessionID: UUID(), actionID: UUID(), again: true, now: now)
        }
        let reopened = try StudyStore(url: url)
        XCTAssertEqual(try StandardStudyMaterialRepository(store: reopened).materials().first?.id, id.id)
        XCTAssertEqual(try StandardStudyRatingRepository(store: reopened).records().first?.missCount, 1)
    }
    func testExpandedSchemaMigratesLegacyDiskStoreWithoutChangingProgress() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        try autoreleasepool {
            let schema = Schema([KanjiDataModel.self, KotobaDataModel.self, WordsProgressModel.self, ReviewRecordModel.self, StudyListModel.self, StudyListMembershipModel.self, DailyGoalSettingsModel.self, PracticeActivityModel.self])
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            context.autosaveEnabled = false
            context.insert(KotobaDataModel(id: "legacy-word", kanji: "森", furigana: "もり", english: [], jlptLevel: .n5, dateAdded: now, addedIndex: 7))
            context.insert(WordsProgressModel(id: "progress", kanjiProgress: 13, kotobaProgress: 41, kanjiLevel: .n4, kotobaLevel: .n3, kanjiIndex: 12, kotobaIndex: 40, lastKotobaUpdated: now, lastKanjiUpdated: now))
            context.insert(StudyListModel(id: "legacy-list", name: "Old list", createdAt: now))
            context.insert(StudyListMembershipModel(listID: "legacy-list", wordID: "legacy-word"))
            try context.save()
        }
        let store = try StudyStore(url: url)
        let context = store.makeContext()
        let progress = try XCTUnwrap(context.fetch(FetchDescriptor<WordsProgressModel>()).first)
        XCTAssertEqual(progress.kotobaProgress, 41)
        XCTAssertEqual(progress.kanjiProgress, 13)
        XCTAssertEqual(progress.kotobaIndex, 40)
        XCTAssertEqual(progress.kanjiIndex, 12)
        XCTAssertEqual(progress.kotobaLevel, .n3)
        XCTAssertEqual(progress.kanjiLevel, .n4)
        XCTAssertEqual(progress.lastKotobaUpdated, now)
        XCTAssertEqual(try context.fetch(FetchDescriptor<KotobaDataModel>()).first?.addedIndex, 7)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyListMembershipModel>()).count, 1)
        let lists = StandardStudyListRepository(store: store)
        XCTAssertEqual(try lists.items(listID: "legacy-list").map(\.id), [.init(kind: .word, id: "legacy-word")])
        _ = try lists.items(listID: "legacy-list")
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<StudyItemMembershipModel>()).count, 1)
        let material = try StandardStudyMaterialRepository(store: store).save(card())
        try lists.setLists(id: .init(kind: material.kind, id: material.id), listIDs: ["legacy-list"])
        let reopened = try StudyStore(url: url)
        XCTAssertEqual(try StandardStudyListRepository(store: reopened).items(listID: "legacy-list").count, 2)
        XCTAssertEqual(try reopened.makeContext().fetch(FetchDescriptor<WordsProgressModel>()).first?.kotobaIndex, 40)
    }
    func testWordDeletionClearsCompositeMembershipAndDifficulty() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(KotobaDataModel(id: "word", kanji: "森", furigana: "もり", english: [], jlptLevel: .n5, dateAdded: now, addedIndex: 0))
        store.context.insert(WordsProgressModel(id: "progress", kanjiProgress: 0, kotobaProgress: 1, kanjiLevel: .n5, kotobaLevel: .n5, kanjiIndex: 0, kotobaIndex: 1, lastKotobaUpdated: now, lastKanjiUpdated: now))
        try store.context.save()
        let id = SavedStudyID(kind: .word, id: "word")
        let lists = StandardStudyListRepository(store: store)
        let list = try lists.create(name: "Trees")
        try lists.setLists(id: id, listIDs: [list.id])
        try StandardStudyRatingRepository(store: store).record(id: id, sessionID: UUID(), actionID: UUID(), again: true, now: now)
        _ = try StandardStudyMutationRepository(store: store).delete(id: id)
        XCTAssertTrue(try lists.items(listID: list.id).isEmpty)
        XCTAssertTrue(try StandardStudyRatingRepository(store: store).records().isEmpty)
        XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<StudyItemMembershipModel>()).isEmpty)
    }
    private enum Failure: Error { case injected }
}
