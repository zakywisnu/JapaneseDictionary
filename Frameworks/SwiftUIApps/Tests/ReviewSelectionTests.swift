import Foundation
import XCTest
@testable import SwiftUIApps

final class ReviewSelectionTests: XCTestCase {
    func testLevelFilterAppliesBeforeLimit() {
        let items = [item("a", level: .n5, date: 1), item("b", level: .n4, date: 2), item("c", level: .n5, date: 2)]
        XCTAssertEqual(ReviewSelection(level: "N5", limit: 1).selected(items).map(\.savedID), ["c"])
        XCTAssertEqual(ReviewSelection(level: "N1", limit: nil).selected(items), [])
    }

    func testNewestFirstUsesSavedIDForDateTiesAndPlacesMissingDatesLast() {
        let items = [item("z", level: .n5, date: nil), item("c", level: .n5, date: 2), item("b", level: .n4, date: 2), item("a", level: .n5, date: 1)]
        XCTAssertEqual(ReviewSelection(level: nil, limit: nil).selected(items).map(\.savedID), ["b", "c", "a", "z"])
        XCTAssertEqual(ReviewSelection(level: nil, limit: 2).selected(items).map(\.savedID), ["b", "c"])
    }

    func testEmptyAndZeroLimitSelectionsAreSafe() {
        XCTAssertEqual(ReviewSelection(level: nil, limit: 20).selected([]), [])
        XCTAssertEqual(ReviewSelection(level: nil, limit: 0).selected([item("a", level: .n5, date: 1)]), [])
    }

    func testSnapshotsKeepSavedIdentityAndDateForBothKinds() {
        let word = item("word-id", level: .n5, date: 42)
        let kanji = ReviewItem(kanji: Kanji(id: "kanji-id", kanji: "一", stroke: 1, onyomi: ["いち"], kunyomi: [], jlptLevel: .n5, meanings: ["One"], dateAdded: Date(timeIntervalSince1970: 24)))
        XCTAssertEqual(word.savedID, "word-id")
        XCTAssertEqual(word.dateAdded, Date(timeIntervalSince1970: 42))
        XCTAssertEqual(kanji.savedID, "kanji-id")
        XCTAssertEqual(kanji.dateAdded, Date(timeIntervalSince1970: 24))
    }

    private func item(_ id: String, level: Kotoba.Level, date: TimeInterval?) -> ReviewItem {
        ReviewItem(word: Kotoba(id: id, kanji: "青", furigana: "あお", english: ["blue"], jlptLevel: level, dateAdded: date.map(Date.init(timeIntervalSince1970:))))
    }
}
