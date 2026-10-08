import XCTest
import SwiftData
@testable import DataKit

final class DailyGoalTests: XCTestCase {
    func testDefaultOffAllowedAndRejectedTargets() throws {
        let repo = StandardDailyGoalRepository(store: try StudyStore(inMemory: true))
        XCTAssertEqual(try repo.target(), 10)
        for target in [5, 10, 20, 30] { try repo.setTarget(target); XCTAssertEqual(try repo.target(), target) }
        try repo.setTarget(nil)
        XCTAssertNil(try repo.target())
        XCTAssertThrowsError(try repo.setTarget(15))
        XCTAssertNil(try repo.target())
    }

    func testDuplicateDayAndKindIdentityRetainHistoryAfterDeletion() throws {
        let store = try populatedStore()
        let repo = StandardDailyGoalRepository(store: store)
        let first = activity(.word)
        try repo.record(first)
        try repo.record(PracticeActivity(id: first.studyID, completedAt: first.completedAt.addingTimeInterval(1), calendar: utc()))
        try repo.record(activity(.kanji))
        XCTAssertEqual(try repo.activities(dayKey: first.dayKey).count, 2)
        let context = store.makeContext()
        for word in try context.fetch(FetchDescriptor<KotobaDataModel>()) { context.delete(word) }
        try context.save()
        try repo.record(first)
        XCTAssertEqual(try repo.activities(dayKey: first.dayKey).count, 2)
        XCTAssertThrowsError(try repo.record(PracticeActivity(id: first.studyID, completedAt: first.completedAt.addingTimeInterval(86400), calendar: utc())))
    }

    func testFailedSaveRollsBackActivityAndTarget() throws {
        let store = try populatedStore()
        let failing = StandardDailyGoalRepository(store: store, save: { _ in throw Failure.injected })
        XCTAssertThrowsError(try failing.record(activity(.word)))
        XCTAssertThrowsError(try failing.setTarget(30))
        let good = StandardDailyGoalRepository(store: store)
        XCTAssertTrue(try good.activities(dayKey: activity(.word).dayKey).isEmpty)
        XCTAssertEqual(try good.target(), 10)
    }

    func testDuplicateRecordDoesNotSaveOrReplaceCapturedTimestamp() throws {
        let store = try populatedStore()
        var saves = 0
        let repo = StandardDailyGoalRepository(store: store, save: { context in
            saves += 1
            try context.save()
        })
        let original = activity(.word)
        try repo.record(original)
        try repo.record(PracticeActivity(id: original.studyID, completedAt: original.completedAt.addingTimeInterval(1), calendar: utc()))
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(try repo.activities(dayKey: original.dayKey), [original])
    }

    func testInvalidActivityAndMissingIdentityCannotBeRecorded() throws {
        let store = try populatedStore()
        let repo = StandardDailyGoalRepository(store: store)
        let original = activity(.word)
        XCTAssertThrowsError(try repo.record(PracticeActivity(key: original.key, dayKey: "2026-02-30", studyID: original.studyID, completedAt: original.completedAt)))
        XCTAssertThrowsError(try repo.record(PracticeActivity(id: .init(kind: .word, id: "missing"), completedAt: original.completedAt, calendar: utc())))
        XCTAssertTrue(try repo.activities(dayKey: original.dayKey).isEmpty)
    }

    func testGregorianKeysAcrossMidnightDSTAndTimezone() throws {
        var calendar = utc()
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        func key(_ components: DateComponents) throws -> String {
            PracticeActivity(id: .init(kind: .word, id: "same"), completedAt: try XCTUnwrap(calendar.date(from: components)), calendar: calendar).dayKey
        }
        XCTAssertEqual(try key(.init(year: 2026, month: 3, day: 7, hour: 23, minute: 59)), "2026-03-07")
        XCTAssertEqual(try key(.init(year: 2026, month: 3, day: 8, hour: 0)), "2026-03-08")
        XCTAssertEqual(try key(.init(year: 2026, month: 3, day: 8, hour: 3)), "2026-03-08")
        let date = try XCTUnwrap(calendar.date(from: .init(year: 2026, month: 3, day: 7, hour: 23)))
        let old = PracticeActivity(id: .init(kind: .word, id: "same"), completedAt: date, calendar: calendar)
        XCTAssertEqual(PracticeActivity(id: old.studyID, completedAt: date, calendar: utc()).dayKey, "2026-03-08")
        XCTAssertEqual(old.dayKey, "2026-03-07")
    }

    private func populatedStore() throws -> StudyStore {
        let store = try StudyStore(inMemory: true)
        store.context.insert(KotobaDataModel(id: "same", kanji: "森", furigana: "もり", english: [], jlptLevel: .n5, dateAdded: nil, addedIndex: nil))
        store.context.insert(KanjiDataModel(id: "same", kanji: "木", stroke: 4, onyomi: [], kunyomi: [], jlptLevel: .n5, meanings: [], dateAdded: nil, addedIndex: nil))
        try store.context.save()
        return store
    }
    private func activity(_ kind: SavedStudyKind) -> PracticeActivity {
        PracticeActivity(id: .init(kind: kind, id: "same"), completedAt: Date(timeIntervalSince1970: 1800000000), calendar: utc())
    }
    private func utc() -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private enum Failure: Error { case injected }
}
