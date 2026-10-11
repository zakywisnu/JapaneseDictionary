import XCTest
import DataKit
import DomainKit
@testable import SwiftUIApps

final class WeeklyRecapPresentationTests: XCTestCase {
    func testFailedReloadClearsStaleSummaryAndRetryIsReadOnly() throws {
        enum Failure: Error { case injected }
        var fails = false, reads = 0, opens = 0
        let useCase = WeeklyRecapUseCase(loadAttempts: { [] }, loadEvents: { [] })
        let model = WeeklyRecapViewModel(load: {
            reads += 1
            if fails { throw Failure.injected }
            return try useCase.execute(now: Date(timeIntervalSince1970: 1_800_000_000), calendar: Calendar(identifier: .gregorian))
        }, open: { _ in opens += 1 })
        model.send(.load)
        XCTAssertNotNil(model.state.recap)
        XCTAssertFalse(model.state.recap!.hasCurrentActivity)
        fails = true; model.send(.load)
        XCTAssertNil(model.state.recap)
        XCTAssertNotNil(model.state.error)
        model.send(.openFocus)
        XCTAssertEqual(opens, 0)
        fails = false; model.send(.retry)
        XCTAssertNil(model.state.error)
        XCTAssertEqual(reads, 3)
        model.send(.openFocus)
        XCTAssertEqual(opens, 1)
    }
    func testAvailableTopicOpensTypedNativeDestination() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = ExerciseSnapshot(id: "q", revision: 1, questionKind: .conjugation, prompt: "行く", acceptedAnswers: ["行って"], explanation: "Te", metadata: .init(activityKind: "conjugation", topicID: "godan-te", source: "Original"))
        let attempts = (0..<2).map { _ in ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .text("wrong"), outcome: .incorrect, submittedAt: now) }
        let useCase = WeeklyRecapUseCase(loadAttempts: { attempts }, loadEvents: { [] }, availableTopics: { ["godan-te": .conjugation] })
        var opened: WeeklyFocusDestination?
        let model = WeeklyRecapViewModel(load: { try useCase.execute(now: now, calendar: .current) }, open: { opened = $0 })
        model.send(.load); model.send(.openFocus)
        XCTAssertEqual(opened, .topic(kind: .conjugation, id: "godan-te"))
    }
}
