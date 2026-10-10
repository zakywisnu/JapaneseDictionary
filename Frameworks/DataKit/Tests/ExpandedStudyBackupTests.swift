import XCTest
import SwiftData
@testable import DataKit

final class ExpandedStudyBackupTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_750_000_000)
    private func repository(_ store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) -> BackupRepository {
        .init(store: store, catalog: .init(words: [], kanjis: []), recoveryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), save: save)
    }
    func testExpandedRoundTripAndLegacyDefaults() throws {
        let store = try StudyStore(inMemory: true)
        let card = StudyMaterial(id: UUID().uuidString, kind: .customCard, prompt: "こんにちは", answer: "Hello", createdAt: date, updatedAt: date)
        let id = SavedStudyID(kind: card.kind, id: card.id)
        store.context.insert(try StudyMaterialModel(value: card))
        store.context.insert(StudyListModel(id: "list", name: "Mixed", createdAt: date))
        store.context.insert(StudyItemMembershipModel(listID: "list", id: id))
        store.context.insert(DifficultyRecordModel(value: .init(id: id, missCount: 2, lastMissDate: date, lastSessionID: UUID(), sessionHadAgain: true, lastActionID: UUID())))
        try store.context.save()
        let repo = repository(store)
        let backup = try repo.validate(repo.export(preferences: .init(todayKind: .customCard)))
        XCTAssertEqual(backup.formatVersion, 6)
        XCTAssertEqual(backup.materials, [card])
        let restored = try StudyStore(inMemory: true)
        try repository(restored).restore(backup, currentPreferences: .init())
        let final = try repository(restored).validate(repository(restored).export(preferences: backup.preferences))
        XCTAssertEqual(final.materials, backup.materials)
        XCTAssertEqual(final.difficulties, backup.difficulties)
        XCTAssertEqual(final.itemMemberships, backup.itemMemberships)
        let legacy = StudyBackup(createdAt: date, catalogFingerprint: backup.catalogFingerprint, words: [], kanjis: [], progress: nil, reviews: [], preferences: .init())
        XCTAssertTrue(try repo.validate(legacy).materials.isEmpty)
    }
    func testMaterialOnlyReviewsRoundTripWithoutCollectionProgress() throws {
        let store = try StudyStore(inMemory: true)
        let card = StudyMaterial(id: UUID().uuidString, kind: .customCard, prompt: "Question", answer: "Answer", createdAt: date, updatedAt: date)
        let review = ReviewRecord(id: .init(kind: .customCard, id: card.id), stage: 1, dueDate: date, lastReviewedAt: date, lastSessionID: UUID(), sessionBaselineStage: 0, sessionHadAgain: false)
        store.context.insert(try StudyMaterialModel(value: card))
        store.context.insert(ReviewRecordModel(record: review))
        try store.context.save()
        let repo = repository(store)
        let backup = try repo.validate(repo.export(preferences: .init()))
        XCTAssertNil(backup.progress)
        XCTAssertEqual(backup.reviews, [review])
        let destination = try StudyStore(inMemory: true)
        let restore = repository(destination)
        try restore.restore(backup, currentPreferences: .init())
        let restored = try restore.validate(restore.export(preferences: .init()))
        XCTAssertNil(restored.progress)
        XCTAssertEqual(restored.reviews, [review])
    }
    func testDuplicateMembershipAcrossLegacyAndCompositeArraysRejects() throws {
        let store = try StudyStore(inMemory: true)
        let repo = repository(store)
        var backup = try repo.validate(repo.export(preferences: .init()))
        backup.memberships = [.init(listID: "list", wordID: "word")]
        backup.itemMemberships = [.init(listID: "list", id: .init(kind: .word, id: "word"))]
        XCTAssertThrowsError(try repo.validate(backup)) { error in
            guard case BackupError.invalid("mixed memberships") = error else {
                return XCTFail("Expected duplicate canonical membership rejection, received \(error)")
            }
        }
    }
    func testFailedReplacementPreservesMaterialsAndRecovery() throws {
        enum Failure: Error { case injected }
        let store = try StudyStore(inMemory: true)
        let card = StudyMaterial(id: UUID().uuidString, kind: .customCard, prompt: "Question", answer: "Answer", createdAt: date, updatedAt: date)
        store.context.insert(try StudyMaterialModel(value: card))
        try store.context.save()
        let valid = try repository(store).validate(repository(store).export(preferences: .init()))
        var replacement = valid
        replacement.materials = []
        let failing = repository(store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failing.restore(replacement, currentPreferences: .init()))
        let preserved = try repository(store).validate(repository(store).export(preferences: .init()))
        XCTAssertEqual(preserved.materials, [card])
    }
    func testLegacyMembershipMigratesWithoutDuplicates() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(StudyListModel(id: "list", name: "List", createdAt: date))
        store.context.insert(StudyListMembershipModel(listID: "list", wordID: "word"))
        store.context.insert(StudyItemMembershipModel(listID: "list", id: .init(kind: .word, id: "word")))
        try store.context.save()
        let context = store.makeContext()
        XCTAssertTrue(try migrateStudyMemberships(context: context))
        try context.save()
        XCTAssertFalse(try migrateStudyMemberships(context: context))
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyItemMembershipModel>()).count, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<StudyListMembershipModel>()).isEmpty)
    }
    func testOrphansUnnormalizedTextAndMissingFormatFourFieldsReject() throws {
        let store = try StudyStore(inMemory: true)
        let repo = repository(store)
        let data = try repo.export(preferences: .init())
        let valid = try repo.validate(data)
        var bad = valid
        bad.itemMemberships = [.init(listID: "missing", id: .init(kind: .customCard, id: "missing"))]
        XCTAssertThrowsError(try repo.restore(bad, currentPreferences: .init()))
        bad = valid
        bad.materials = [.init(id: UUID().uuidString, kind: .customCard, prompt: " padded ", answer: "answer", createdAt: date, updatedAt: date)]
        XCTAssertThrowsError(try repo.validate(bad))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "difficulties")
        XCTAssertThrowsError(try repo.validate(JSONSerialization.data(withJSONObject: json)))
    }
}
