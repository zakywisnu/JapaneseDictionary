import XCTest
import DataKit
import DomainKit
@testable import SwiftUIApps

@MainActor final class ContextReviewPresentationTests: XCTestCase {
    func testMixedAndNonWordSessionsDoNotSupportContext() {
        let material = StudyMaterial(id: "card", kind: .customCard, prompt: "Prompt", answer: "Answer", createdAt: Date(), updatedAt: Date())
        let item = ReviewItem(material: material)
        let word = ReviewItem(word: Kotoba(id: "word", kanji: "青い", furigana: "あおい", english: ["blue"], jlptLevel: .n5, dateAdded: nil))
        XCTAssertTrue(ReviewSession(useSentenceContext: true, items: [word]).supportsSentenceContext)
        XCTAssertFalse(ReviewSession(useSentenceContext: true, items: [word, item]).supportsSentenceContext)
        XCTAssertFalse(ReviewSession(useSentenceContext: true, items: [item]).supportsSentenceContext)
        XCTAssertFalse(ReviewSession(useSentenceContext: true, items: []).supportsSentenceContext)
    }
    func testContextAudioAndAnswerRemainHiddenUntilReveal() {
        let material = StudyMaterial(id: "card", kind: .customCard, prompt: "Prompt", answer: "Answer", reading: "あおい", createdAt: Date(), updatedAt: Date())
        var item = ReviewItem(material: material)
        item.context = .init(stableID: "blue", word: .init(headword: "青い", reading: "あおい", level: "N5"), verifiedMeanings: ["blue"], cloze: "空は＿＿です。", japanese: "空は青いです。", reading: "そらはあおいです。", translation: "The sky is blue.", source: "Original")
        var actions = 0
        let viewModel = ReviewViewModel(session: .init(useSentenceContext: true, items: [item]), recordAction: { _, _, _, _, _, _ in actions += 1 })
        XCTAssertFalse(viewModel.state.isAnswerVisible); XCTAssertTrue(viewModel.state.pronunciationReadings.isEmpty)
        viewModel.send(.rate(.gotIt)); XCTAssertEqual(actions, 0)
        viewModel.send(.reveal); XCTAssertEqual(viewModel.state.pronunciationReadings, ["そらはあおいです。"])
        viewModel.send(.rate(.again)); XCTAssertEqual(actions, 1); XCTAssertFalse(viewModel.state.isAnswerVisible)
    }
}
