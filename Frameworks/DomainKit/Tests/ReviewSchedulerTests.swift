import XCTest
import DataKit
import SwiftData
@testable import DomainKit

final class ReviewSchedulerTests: XCTestCase {
    func testStagesAdvanceOnceAndResetAfterAgain() {
        let scheduler = ReviewScheduler()
        XCTAssertEqual(scheduler.nextStage(baseline: nil, hadAgain: false), 0)
        XCTAssertEqual(scheduler.nextStage(baseline: 2, hadAgain: false), 3)
        XCTAssertEqual(scheduler.nextStage(baseline: 4, hadAgain: false), 4)
        XCTAssertEqual(scheduler.nextStage(baseline: 4, hadAgain: true), 0)
    }

    func testCalendarDayDatesAcrossDSTAndMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 59)))
        let next = try ReviewScheduler().dueDate(stage: 0, now: now, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: next), DateComponents(year: 2026, month: 3, day: 8, hour: 0))
        let threeDays = try ReviewScheduler().dueDate(stage: 1, now: now, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour], from: threeDays), DateComponents(year: 2026, month: 3, day: 10, hour: 0))
        XCTAssertEqual(threeDays.timeIntervalSince(calendar.startOfDay(for: now)), 71 * 3_600)
    }

    func testSameSessionRetriesDoNotAdvanceAndAgainPersists() throws {
        let store = try makeStore()
        let repo = StandardReviewRepository(context: store.context)
        let useCase = DefaultRecordReviewUseCase(repository: repo, calendar: utcCalendar())
        let id = SavedStudyID(kind: .word, id: "a")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let firstSession = UUID()
        try useCase.execute(id: id, sessionID: firstSession, rating: .gotIt, now: now)
        try useCase.execute(id: id, sessionID: firstSession, rating: .gotIt, now: now)
        XCTAssertEqual(try repo.records().first?.stage, 0)
        let secondSession = UUID()
        try useCase.execute(id: id, sessionID: secondSession, rating: .gotIt, now: now)
        XCTAssertEqual(try repo.records().first?.stage, 1)
        try useCase.execute(id: id, sessionID: secondSession, rating: .again, now: now)
        try useCase.execute(id: id, sessionID: secondSession, rating: .gotIt, now: now)
        XCTAssertEqual(try repo.records().first?.stage, 0)
        XCTAssertEqual(try repo.records().first?.sessionBaselineStage, 0)
        XCTAssertEqual(try repo.records().first?.sessionHadAgain, true)
    }

    func testDueItemsJoinSavedValuesAndSortByDateThenID() throws {
        let store = try makeStore()
        let repo = StandardReviewRepository(context: store.context)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try repo.save(ReviewRecord(id: .init(kind: .word, id: "b"), stage: 1, dueDate: now.addingTimeInterval(-1), lastReviewedAt: now.addingTimeInterval(-100), lastSessionID: UUID(), sessionBaselineStage: 0, sessionHadAgain: false))
        try repo.save(ReviewRecord(id: .init(kind: .word, id: "c"), stage: 1, dueDate: now.addingTimeInterval(1), lastReviewedAt: now, lastSessionID: UUID(), sessionBaselineStage: 0, sessionHadAgain: false))
        let due = try DefaultGetDueReviewsUseCase(repository: repo).execute(kind: .word, now: now)
        XCTAssertEqual(due.map(\.item.id.id), ["a", "b"])
        XCTAssertEqual(due.first?.item.headword, "森a")
        XCTAssertEqual(due.first?.item.meanings, ["forest"])
        XCTAssertEqual(try DefaultGetDueReviewsUseCase(repository: repo).execute(kind: .kanji, now: now).count, 0)
    }

    func testUnratedItemIsDueWhenClockMovesBeforeAddedDate() throws {
        let store = try makeStore()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let word = try XCTUnwrap(store.context.fetch(FetchDescriptor<KotobaDataModel>()).first)
        word.dateAdded = now.addingTimeInterval(86_400)
        try store.context.save()
        let due = try DefaultGetDueReviewsUseCase(repository: StandardReviewRepository(store: store)).execute(kind: .word, now: now)
        XCTAssertTrue(due.contains { $0.item.id.id == word.id })
    }

    private func makeStore() throws -> StudyStore {
        let store = try StudyStore(inMemory: true)
        for id in ["c", "b", "a"] {
            store.context.insert(KotobaDataModel(id: id, kanji: "森" + id, furigana: "もり", english: [ArrayString(value: "forest")], jlptLevel: .n5, dateAdded: nil, addedIndex: nil))
        }
        try store.context.save()
        return store
    }
    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
