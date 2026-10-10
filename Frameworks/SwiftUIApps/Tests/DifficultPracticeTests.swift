import XCTest
import DataKit
@testable import SwiftUIApps

final class DifficultPracticeTests: XCTestCase {
    func testUnspecifiedCustomCardsRemainSelectableWithoutJLPTLevel() {
        let card = StudyMaterial(id: UUID().uuidString, kind: .customCard, prompt: "こんにちは", answer: "Hello", createdAt: Date(), updatedAt: Date())
        let id = SavedStudyID(kind: .customCard, id: card.id)
        let model = DifficultPracticeViewModel(load: {
            .init(items: [.init(material: card)], records: [.init(id: id, missCount: 1, lastMissDate: Date(), lastSessionID: UUID(), sessionHadAgain: true, lastActionID: UUID())], lists: [], memberships: [:])
        })
        model.send(.load)
        model.send(.setLevel("Unspecified"))
        XCTAssertEqual(model.selected.map(\.compositeID), [id])
    }
    func testFiltersIntersectAndSortMissesBeforeDatesWithCompositeIdentity() {
        let word = ReviewItem(word: .init(id: "same", kanji: "森", furigana: "もり", english: ["forest"], jlptLevel: .n5))
        let kanji = ReviewItem(kanji: .init(id: "same", kanji: "木", stroke: 4, onyomi: [], kunyomi: [], jlptLevel: .n5, meanings: ["tree"]))
        let record: (SavedStudyKind, Int, Double) -> DifficultyRecord = { kind, count, date in
            .init(id: .init(kind: kind, id: "same"), missCount: count, lastMissDate: Date(timeIntervalSince1970: date), lastSessionID: UUID(), sessionHadAgain: true, lastActionID: UUID())
        }
        let model = DifficultPracticeViewModel(load: {
            .init(items: [word, kanji], records: [record(.word, 3, 1), record(.kanji, 1, 100)], lists: [.init(id: "list", name: "Forest", createdAt: Date(), wordCount: 1)], memberships: ["list": [.init(kind: .kanji, id: "same")]])
        })
        model.send(.load)
        XCTAssertEqual(model.selected.map(\.compositeID.kind), [.word, .kanji])
        model.send(.setList("list"))
        XCTAssertEqual(model.selected.map(\.compositeID.kind), [.kanji])
        model.send(.setKind(.word))
        XCTAssertTrue(model.selected.isEmpty)
        model.send(.clearFilters)
        model.send(.setLimit(1))
        XCTAssertEqual(model.selected.map(\.compositeID.kind), [.word])
        model.send(.setLevel("Unspecified"))
        XCTAssertTrue(model.selected.isEmpty)
    }

    func testLoadErrorRetainsFiltersAndCanRetryWithoutInventedItems() {
        var fail = true
        let model = DifficultPracticeViewModel(load: {
            if fail { throw Failure.save }
            return .init(items: [], records: [], lists: [], memberships: [:])
        })
        model.send(.setKind(.kanji))
        model.send(.load)
        XCTAssertNotNil(model.state.error)
        XCTAssertTrue(model.selected.isEmpty)
        fail = false
        model.send(.load)
        XCTAssertNil(model.state.error)
        XCTAssertEqual(model.state.kind, .kanji)
    }
    private enum Failure: Error { case save }
}
