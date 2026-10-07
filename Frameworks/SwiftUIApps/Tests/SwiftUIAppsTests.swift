import Foundation
import XCTest
import DataKit
import DomainKit
@testable import SwiftUIApps

final class SwiftUIAppsTests: XCTestCase {
    @MainActor
    func testRatingsRequireRevealAndHideTheNextAnswer() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青"), word("会う")]))
        model.send(.rate(.gotIt))
        XCTAssertEqual(model.state.currentItem?.headword, "青")
        XCTAssertEqual(model.state.remainingCount, 2)
        model.send(.reveal)
        model.send(.rate(.again))
        XCTAssertEqual(model.state.currentItem?.headword, "会う")
        XCTAssertFalse(model.state.isAnswerVisible)
        XCTAssertEqual(model.state.repeatAttempts, 1)
        model.send(.reveal)
        model.send(.rate(.gotIt))
        XCTAssertEqual(model.state.currentItem?.headword, "青")
    }

    @MainActor
    func testDoubleGotItDoesNotConsumeAnUnrevealedItem() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青"), word("会う")]))
        model.send(.reveal)
        model.send(.rate(.gotIt))
        model.send(.rate(.gotIt))
        XCTAssertEqual(model.state.currentItem?.headword, "会う")
        XCTAssertEqual(model.state.remainingCount, 1)
        XCTAssertFalse(model.state.isComplete)
    }

    @MainActor
    func testOneItemAgainResetsRecallAndScrollThenGotItCompletes() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青")]))
        model.send(.reveal)
        let initialRevision = model.state.presentationRevision
        model.send(.rate(.again))
        XCTAssertEqual(model.state.currentItem?.headword, "青")
        XCTAssertFalse(model.state.isAnswerVisible)
        XCTAssertGreaterThan(model.state.presentationRevision, initialRevision)
        XCTAssertFalse(model.state.isComplete)
        model.send(.reveal)
        model.send(.rate(.gotIt))
        model.send(.rate(.gotIt))
        XCTAssertTrue(model.state.isComplete)
        XCTAssertNil(model.state.currentItem)
        XCTAssertEqual(model.state.distinctItemCount, 1)
    }

    @MainActor
    func testRestartRestoresOriginalUniqueQueueAndResetsAttempts() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青"), word("会う"), word("青")]))
        model.send(.reveal)
        model.send(.rate(.again))
        model.send(.reveal)
        model.send(.rate(.gotIt))
        model.send(.restart)
        XCTAssertEqual(model.state.currentItem?.headword, "青")
        XCTAssertEqual(model.state.remainingCount, 2)
        XCTAssertEqual(model.state.distinctItemCount, 2)
        XCTAssertEqual(model.state.repeatAttempts, 0)
        XCTAssertFalse(model.state.isAnswerVisible)
        XCTAssertFalse(model.state.isComplete)
    }

    @MainActor
    func testEmptySessionHandlesEveryAction() {
        let model = ReviewViewModel(session: .init(kind: .kanji, items: []))
        for action in [ReviewViewModel.Action.reveal, .rate(.again), .rate(.gotIt), .restart] { model.send(action) }
        XCTAssertNil(model.state.currentItem)
        XCTAssertEqual(model.state.remainingCount, 0)
        XCTAssertEqual(model.state.repeatAttempts, 0)
        XCTAssertFalse(model.state.isAnswerVisible)
    }

    func testWordSnapshotUsesSavedDefinitionsAndOmitsDuplicateReading() {
        let word = Kotoba(id: "saved", kanji: "", furigana: "ああ", english: ["Ah!", "Oh!"], jlptLevel: .n5)
        let snapshot = ReviewItem(word: word)
        XCTAssertEqual(snapshot.headword, "ああ")
        XCTAssertNil(snapshot.reading)
        XCTAssertEqual(snapshot.exampleWordKey, ExampleWordKey(headword: "ああ", reading: "ああ", level: "N5"))
        XCTAssertEqual(snapshot.meanings, ["Ah!", "Oh!"])
    }

    func testKanjiSnapshotPreservesSeparateReadingsAndStrokes() {
        let kanji = Kanji(id: "saved", kanji: "一", stroke: 1, onyomi: ["いち"], kunyomi: ["ひと.つ"], jlptLevel: .n5, meanings: ["One"])
        let snapshot = ReviewItem(kanji: kanji)
        XCTAssertEqual(snapshot.headword, "一")
        XCTAssertEqual(snapshot.onyomi, ["いち"])
        XCTAssertEqual(snapshot.kunyomi, ["ひと.つ"])
        XCTAssertEqual(snapshot.strokes, 1)
    }

    @MainActor
    func testDueSaveFailureRetainsAnswerAndRetryUsesSameSession() {
        var calls: [(SavedStudyID, UUID, RecallRating)] = []
        var shouldFail = true
        let session = ReviewSession(kind: .words, items: [word("青")], origin: .due)
        let model = ReviewViewModel(session: session, recordRating: { id, sessionID, rating, _ in
            calls.append((id, sessionID, rating))
            if shouldFail { throw NSError(domain: "save", code: 1) }
        })
        model.send(.rate(.again))
        XCTAssertTrue(calls.isEmpty)
        model.send(.reveal)
        model.send(.rate(.again))
        XCTAssertEqual(model.state.currentItem?.headword, "青")
        XCTAssertTrue(model.state.isAnswerVisible)
        XCTAssertNotNil(model.state.saveError)
        XCTAssertEqual(model.state.repeatAttempts, 0)
        model.send(.rate(.gotIt))
        XCTAssertEqual(calls.count, 1)
        shouldFail = false
        model.send(.retry)
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].1, calls[1].1)
        XCTAssertEqual(calls[1].2, .again)
        XCTAssertEqual(model.state.repeatAttempts, 1)
        XCTAssertFalse(model.state.isAnswerVisible)
        XCTAssertNil(model.state.saveError)
        model.send(.reveal)
        model.send(.rate(.gotIt))
        XCTAssertTrue(model.state.isComplete)
        XCTAssertEqual(calls[2].1, calls[0].1)
    }

    @MainActor
    func testCompletedDueSessionCannotRestartItsStaleSnapshot() {
        var saves = 0
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青")], origin: .due), recordRating: { _, _, _, _ in saves += 1 })
        model.send(.reveal)
        model.send(.rate(.gotIt))
        let sessionID = model.state.session.id
        model.send(.restart)
        model.send(.reveal)
        model.send(.rate(.gotIt))
        XCTAssertTrue(model.state.isComplete)
        XCTAssertEqual(model.state.session.id, sessionID)
        XCTAssertEqual(saves, 1)
    }

    @MainActor
    func testPracticeOriginsNeverPersistRatings() {
        for origin in [ReviewOrigin.today, .collection] {
            var saves = 0
            let model = ReviewViewModel(session: .init(kind: .words, items: [word("青")], origin: origin), recordRating: { _, _, _, _ in saves += 1 })
            model.send(.reveal)
            model.send(.rate(.gotIt))
            XCTAssertTrue(model.state.isComplete)
            XCTAssertEqual(saves, 0)
        }
    }

    func testDueSnapshotRetainsKanaOnlyExampleKey() throws {
        let store = try StudyStore(inMemory: true)
        store.context.insert(KotobaDataModel(id: "kana", kanji: "", furigana: "ああ", english: [ArrayString(value: "Ah!")], jlptLevel: .n5, dateAdded: nil, addedIndex: nil))
        try store.context.save()
        let saved = try XCTUnwrap(StandardReviewRepository(store: store).savedItems(kind: .word).first)
        let item = ReviewItem(saved: saved)
        XCTAssertNil(item.reading)
        XCTAssertEqual(item.exampleWordKey, ExampleWordKey(headword: "ああ", reading: "ああ", level: "N5"))
    }

    private func word(_ headword: String) -> ReviewItem {
        ReviewItem(word: Kotoba(id: headword, kanji: headword, furigana: "あお", english: ["blue"], jlptLevel: .n5))
    }
}
