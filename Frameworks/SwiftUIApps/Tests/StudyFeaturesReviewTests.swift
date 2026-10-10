import XCTest
import DataKit
@testable import SwiftUIApps

@MainActor
final class StudyFeaturesReviewTests: XCTestCase {
    func testMixedKindsWithSameRawIDRemainSeparateQueueItems() {
        let word = ReviewItem(word: .init(id: "same", kanji: "森", furigana: "もり", english: ["forest"], jlptLevel: .n5))
        let kanji = ReviewItem(kanji: .init(id: "same", kanji: "木", stroke: 4, onyomi: ["もく"], kunyomi: ["き"], jlptLevel: .n5, meanings: ["tree"]))
        let model = ReviewViewModel(session: .init(kind: .words, items: [word, kanji]))
        XCTAssertEqual(model.state.distinctItemCount, 2)
        model.send(.reveal)
        model.send(.rate(.gotIt))
        XCTAssertEqual(model.state.currentItem?.headword, "木")
        XCTAssertFalse(model.state.isComplete)
    }
    func testFailedCompletionKeepsAnswerAndRetriesOriginalDateAcrossMidnight() {
        var date = Date(timeIntervalSince1970: 100)
        var attempts: [Date] = []
        let model = ReviewViewModel(session: session(), recordPractice: { _, timestamp in
            attempts.append(timestamp)
            if attempts.count == 1 { throw Failure.save }
        }, now: { date })
        XCTAssertEqual(model.state.pronunciationReadings, [])
        model.send(.reveal)
        XCTAssertEqual(model.state.pronunciationReadings, ["もり"])
        model.send(.rate(.gotIt))
        XCTAssertTrue(model.state.isAnswerVisible)
        XCTAssertFalse(model.state.isComplete)
        XCTAssertNotNil(model.state.saveError)
        date = Date(timeIntervalSince1970: 100_000)
        model.send(.retry)
        XCTAssertEqual(attempts, [Date(timeIntervalSince1970: 100), Date(timeIntervalSince1970: 100)])
        XCTAssertTrue(model.state.isComplete)
        XCTAssertEqual(model.state.pronunciationReadings, [])
    }

    func testAgainDoesNotRecordCompletionAndHiddenAnswerCannotBeRated() {
        var count = 0
        let model = ReviewViewModel(session: session(), recordPractice: { _, _ in count += 1 })
        model.send(.rate(.gotIt))
        XCTAssertEqual(count, 0)
        model.send(.reveal)
        model.send(.rate(.again))
        XCTAssertEqual(count, 0)
        XCTAssertFalse(model.state.isAnswerVisible)
    }

    private func session() -> ReviewSession {
        .init(kind: .words, items: [.init(word: .init(id: "word", kanji: "森", furigana: "もり", english: ["forest"], jlptLevel: .n5))])
    }
    private enum Failure: Error { case save }
}
