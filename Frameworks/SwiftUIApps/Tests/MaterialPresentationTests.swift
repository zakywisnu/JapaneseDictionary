import XCTest
import DataKit
@testable import SwiftUIApps

final class MaterialPresentationTests: XCTestCase {
    private enum Failure: Error { case injected }
    private var card: StudyMaterial {
        .init(id: "card", kind: .customCard, prompt: "猫", answer: "cat", reading: "ねこ", category: "other", createdAt: .distantPast, updatedAt: .distantPast)
    }

    @MainActor func testSpeakingUsesOnlySuppliedSentenceAndCardReadings() {
        XCTAssertEqual(MaterialDetailView.speakingTarget(for: card)?.suppliedReading, "ねこ")
        var value = card; value.reading = nil
        XCTAssertNil(MaterialDetailView.speakingTarget(for: value))
        value.reading = "cat"
        XCTAssertNil(MaterialDetailView.speakingTarget(for: value))
        value.reading = "ねこ"; value.kind = .grammar
        XCTAssertNil(MaterialDetailView.speakingTarget(for: value))
        value.kind = .sentence; value.prompt = "猫です。"; value.reading = "ねこです。"
        XCTAssertEqual(MaterialDetailView.speakingTarget(for: value)?.prompt, "猫です。")
    }
    func testFailedSaveRetainsDraftAndAllowsRetry() {
        var fails = true
        let model = CustomCardEditorViewModel(material: nil, save: { value in
            if fails { throw Failure.injected }; return value
        })
        model.state.draft.prompt = "  猫  "
        model.state.draft.answer = "cat"
        model.send(.save)
        XCTAssertEqual(model.state.draft.prompt, "  猫  ")
        XCTAssertNotNil(model.state.errorMessage)
        XCTAssertNil(model.state.savedMaterial)
        fails = false
        model.send(.save)
        XCTAssertEqual(model.state.savedMaterial?.prompt, "猫")
    }

    func testRecallEditRequiresConfirmationAndNotesDoNot() {
        var saves = 0
        let model = CustomCardEditorViewModel(material: card, save: { saves += 1; return $0 })
        model.state.draft.notes = "pet"
        model.send(.save)
        XCTAssertEqual(saves, 1)
        let changed = CustomCardEditorViewModel(material: card, save: { saves += 1; return $0 })
        changed.state.draft.answer = "a cat"
        changed.send(.save)
        XCTAssertTrue(changed.state.needsResetConfirmation)
        XCTAssertEqual(saves, 1)
        changed.send(.confirmSave)
        XCTAssertEqual(saves, 2)
    }

    func testEmptyIntersectionAndClearFilters() {
        let card = card
        let model = MaterialLibraryViewModel(mode: .saved(.customCard), loadSaved: { [card] }, loadCatalog: { [] })
        model.send(.load)
        model.send(.levelChanged("N5"))
        XCTAssertTrue(model.state.results.isEmpty)
        XCTAssertEqual(model.state.loadState, .loaded)
        model.send(.clearFilters)
        XCTAssertEqual(model.state.results, [card])
    }

    func testDetailKeepsSuppliedContentAfterSaveFailure() {
        let card = card
        let model = MaterialDetailViewModel(material: card, mode: .bundled, loadSaved: { [] }, save: { _ in throw Failure.injected }, delete: { _ in })
        model.send(.load)
        model.send(.save)
        XCTAssertEqual(model.state.material.answer, "cat")
        XCTAssertEqual(model.state.material.reading, "ねこ")
        XCTAssertTrue(model.canSave)
        XCTAssertNotNil(model.state.errorMessage)
    }
    @MainActor
    func testAtomicAgainRetryRetainsActionAndOriginalDay() {
        let firstDay = Date(timeIntervalSince1970: 1_000)
        var clock = firstDay
        var attempts: [(SavedStudyID, UUID, UUID, Date, Bool)] = []
        var failing = true
        let model = ReviewViewModel(session: ReviewSession(items: [ReviewItem(material: card)], origin: .collection), now: { clock }, recordAction: { id, session, action, _, date, due in
            attempts.append((id, session, action, date, due))
            if failing { throw Failure.injected }
        })
        model.send(.reveal)
        model.send(.rate(.again))
        XCTAssertTrue(model.state.isAnswerVisible)
        XCTAssertEqual(model.state.repeatAttempts, 0)
        failing = false
        clock = firstDay.addingTimeInterval(86_400)
        model.send(.retry)
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts[0].0, SavedStudyID(kind: .customCard, id: "card"))
        XCTAssertEqual(attempts[0].1, attempts[1].1)
        XCTAssertEqual(attempts[0].2, attempts[1].2)
        XCTAssertEqual(attempts[1].3, firstDay)
        XCTAssertFalse(attempts[1].4)
        XCTAssertEqual(model.state.repeatAttempts, 1)
        XCTAssertFalse(model.state.isAnswerVisible)
        model.send(.reveal)
        model.send(.rate(.again))
        XCTAssertNotEqual(attempts[1].2, attempts[2].2)
    }

    func testUnspecifiedLevelSelectsOnlyCardsWithoutLevel() {
        var specified = card
        specified.id = "specified"
        specified.level = "N5"
        let items = [ReviewItem(material: card), ReviewItem(material: specified)]
        XCTAssertEqual(ReviewSelection(level: "", limit: nil).selected(items).map(\.savedID), ["card"])
        let library = MaterialLibraryViewModel(mode: .saved(.customCard), loadSaved: { [self.card, specified] }, loadCatalog: { [] })
        library.send(.load)
        library.send(.levelChanged(""))
        XCTAssertEqual(library.state.results.map(\.id), ["card"])
    }

}
