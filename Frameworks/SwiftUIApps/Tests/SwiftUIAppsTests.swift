import Foundation
import XCTest
@testable import SwiftUIApps

final class SwiftUIAppsTests: XCTestCase {
    @MainActor
    func testNextRequiresRevealAndHidesTheNextAnswer() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青"), word("会う")]))
        model.send(.next)
        XCTAssertEqual(model.state.currentItem?.headword, "青")
        model.send(.reveal)
        XCTAssertTrue(model.state.isAnswerVisible)
        model.send(.next)
        XCTAssertEqual(model.state.currentItem?.headword, "会う")
        XCTAssertFalse(model.state.isAnswerVisible)
        XCTAssertFalse(model.state.isComplete)
    }

    @MainActor
    func testOneItemFinishesWithoutAdvancingPastTheEnd() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青")]))
        model.send(.reveal)
        model.send(.next)
        model.send(.next)
        XCTAssertTrue(model.state.isComplete)
        XCTAssertEqual(model.state.index, 0)
        XCTAssertEqual(model.state.currentItem?.headword, "青")
    }

    @MainActor
    func testPreviousReturnsToRecallAndCannotUnderflow() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青"), word("会う")]))
        model.send(.reveal)
        model.send(.next)
        model.send(.reveal)
        model.send(.previous)
        model.send(.previous)
        XCTAssertEqual(model.state.index, 0)
        XCTAssertFalse(model.state.isAnswerVisible)
        XCTAssertFalse(model.state.isComplete)
    }

    @MainActor
    func testRepeatRestoresTheOriginalSnapshot() {
        let model = ReviewViewModel(session: .init(kind: .words, items: [word("青"), word("会う")]))
        for _ in 0..<2 { model.send(.reveal); model.send(.next) }
        model.send(.restart)
        XCTAssertEqual(model.state.currentItem?.headword, "青")
        XCTAssertEqual(model.state.session.items.map(\.headword), ["青", "会う"])
        XCTAssertFalse(model.state.isAnswerVisible)
        XCTAssertFalse(model.state.isComplete)
    }

    @MainActor
    func testEmptySessionHandlesEveryAction() {
        let model = ReviewViewModel(session: .init(kind: .kanji, items: []))
        for action in [ReviewViewModel.Action.reveal, .next, .previous, .restart] { model.send(action) }
        XCTAssertNil(model.state.currentItem)
        XCTAssertEqual(model.state.index, 0)
        XCTAssertFalse(model.state.isComplete)
        XCTAssertFalse(model.state.isAnswerVisible)
    }

    func testWordSnapshotUsesSavedDefinitionsAndOmitsDuplicateReading() {
        let word = Kotoba(id: "saved", kanji: "", furigana: "ああ", english: ["Ah!", "Oh!"], jlptLevel: .n5)
        let snapshot = ReviewItem(word: word)
        XCTAssertEqual(snapshot.headword, "ああ")
        XCTAssertNil(snapshot.reading)
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

    private func word(_ headword: String) -> ReviewItem {
        ReviewItem(word: Kotoba(id: headword, kanji: headword, furigana: "あお", english: ["blue"], jlptLevel: .n5))
    }
}
