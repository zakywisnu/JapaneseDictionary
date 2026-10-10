import XCTest
import SwiftData
@testable import DataKit

final class StudyListTests: XCTestCase {
    func testMixedMembershipIdentityAndLegacyConversion() throws {
        let store = try fixture()
        let repository = StandardStudyListRepository(store: store)
        let list = try repository.create(name: "Mixed")
        let context = store.makeContext()
        context.insert(StudyListMembershipModel(listID: list.id, wordID: "word"))
        context.insert(KanjiDataModel(id: "word", kanji: "木", stroke: 4, onyomi: [], kunyomi: [], jlptLevel: .n5, meanings: [], dateAdded: nil, addedIndex: nil))
        try context.save()
        try repository.setLists(id: .init(kind: .kanji, id: "word"), listIDs: [list.id])
        XCTAssertEqual(Set(try repository.items(listID: list.id).map(\.id)), [.init(kind: .word, id: "word"), .init(kind: .kanji, id: "word")])
        XCTAssertEqual(try repository.lists().first?.itemCount, 2)
        _ = try repository.items(listID: list.id)
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<StudyItemMembershipModel>()).count, 2)
        XCTAssertTrue(try store.makeContext().fetch(FetchDescriptor<StudyListMembershipModel>()).isEmpty)
        try repository.removeItem(listID: list.id, id: .init(kind: .kanji, id: "word"))
        XCTAssertEqual(try repository.items(listID: list.id).map(\.id.kind), [.word])
    }
    private func fixture() throws -> StudyStore {
        let store = try StudyStore(inMemory: true)
        store.context.insert(KotobaDataModel(id: "word", kanji: "森", furigana: "もり", english: [], jlptLevel: .n5, dateAdded: Date(), addedIndex: 0))
        try store.context.save()
        return store
    }

    func testMembershipReplacementIsIdempotentAndListDeletionKeepsWord() throws {
        let store = try fixture()
        let repository = StandardStudyListRepository(store: store)
        let travel = try repository.create(name: "Travel")
        let exam = try repository.create(name: "Exam")
        try repository.setLists(wordID: "word", listIDs: [travel.id, exam.id])
        try repository.setLists(wordID: "word", listIDs: [travel.id, exam.id])
        XCTAssertEqual(try repository.listIDs(wordID: "word"), [travel.id, exam.id])
        XCTAssertEqual(try repository.words(listID: travel.id).count, 1)
        try repository.delete(id: travel.id)
        XCTAssertEqual(try repository.listIDs(wordID: "word"), [exam.id])
        XCTAssertEqual(try store.makeContext().fetch(FetchDescriptor<KotobaDataModel>()).count, 1)
    }

    func testNamesAndReferencesAreValidatedBeforeMutation() throws {
        let store = try fixture()
        let repository = StandardStudyListRepository(store: store)
        let list = try repository.create(name: " Travel ")
        XCTAssertEqual(list.name, "Travel")
        for name in ["ＴＲＡＶＥＬ", "travel", "  ", String(repeating: "a", count: 61)] {
            XCTAssertThrowsError(try repository.create(name: name))
        }
        XCTAssertThrowsError(try repository.setLists(wordID: "missing", listIDs: [list.id]))
        try repository.setLists(wordID: "word", listIDs: [list.id])
        XCTAssertThrowsError(try repository.setLists(wordID: "word", listIDs: ["missing"]))
        XCTAssertEqual(try repository.listIDs(wordID: "word"), [list.id])
    }

    func testSaveFailureRollsBackNameAndMemberships() throws {
        enum Failure: Error { case save }
        let store = try fixture()
        let repository = StandardStudyListRepository(store: store)
        let list = try repository.create(name: "Travel")
        try repository.setLists(wordID: "word", listIDs: [list.id])
        let failing = StandardStudyListRepository(store: store, save: { _ in throw Failure.save })
        XCTAssertThrowsError(try failing.rename(id: list.id, name: "Changed"))
        XCTAssertThrowsError(try failing.setLists(wordID: "word", listIDs: []))
        XCTAssertThrowsError(try failing.delete(id: list.id))
        XCTAssertEqual(try repository.lists().first?.name, "Travel")
        XCTAssertEqual(try repository.listIDs(wordID: "word"), [list.id])
    }

    func testInjectedIdentityDateAndStableOrdering() throws {
        let store = try fixture()
        var sequence = ["z", "a", "b"]
        let date = Date(timeIntervalSince1970: 123)
        let repository = StandardStudyListRepository(store: store, makeID: { sequence.removeFirst() }, now: { date })
        let zebra = try repository.create(name: "Zebra")
        let apple = try repository.create(name: "Apple")
        XCTAssertEqual(zebra.id, "z")
        XCTAssertEqual(apple.createdAt, date)
        XCTAssertEqual(try repository.lists().map(\.id), ["a", "z"])
        try repository.setLists(wordID: "word", listIDs: [apple.id])
        try repository.removeWord(listID: apple.id, wordID: "word")
        try repository.removeWord(listID: apple.id, wordID: "word")
        XCTAssertEqual(try repository.lists().first?.wordCount, 0)
    }

    func testActivityUsesLocalGregorianDayAndUnambiguousKeys() {
        var calendar = Calendar(identifier: .buddhist)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        let activity = PracticeActivity(id: SavedStudyID(kind: .word, id: "a:b"), completedAt: Date(timeIntervalSince1970: 0), calendar: calendar)
        XCTAssertEqual(activity.dayKey, "1970-01-01")
        XCTAssertNotEqual(StudyListMembershipModel.membershipKey(listID: "a:b", wordID: "c"), StudyListMembershipModel.membershipKey(listID: "a", wordID: "b:c"))
        XCTAssertEqual(DailyGoalSettings().target, 10)
    }
}
