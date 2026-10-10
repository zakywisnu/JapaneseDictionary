import XCTest
import DataKit
@testable import SwiftUIApps

final class DailyStudyPlanTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1000)
    private func item(_ id: String) -> ReviewItem {
        .init(material: .init(id: id, kind: .customCard, prompt: id, answer: "Answer", createdAt: now, updatedAt: now))
    }
    private func review(_ item: ReviewItem, due: Double) -> ReviewRecord {
        .init(id: item.compositeID, stage: 0, dueDate: Date(timeIntervalSince1970: due), lastReviewedAt: now, lastSessionID: UUID(), sessionBaselineStage: nil, sessionHadAgain: false)
    }
    private func difficulty(_ item: ReviewItem) -> DifficultyRecord {
        .init(id: item.compositeID, missCount: 2, lastMissDate: now, lastSessionID: UUID(), sessionHadAgain: true, lastActionID: UUID())
    }
    func testPrioritiesExcludeDuplicatesCompletedAndFutureReviews() {
        let due = item("due"), hard = item("hard"), first = item("first"), complete = item("complete"), future = item("future")
        let snapshot = DailyStudyPlanViewModel.Snapshot(items: [first, future, hard, due, complete, due], reviews: [review(due, due: 900), review(hard, due: 2000), review(future, due: 2000)], difficulties: [difficulty(due), difficulty(hard)], completed: [complete.compositeID], target: 10)
        let model = DailyStudyPlanViewModel(load: { snapshot }, now: { self.now })
        model.send(.load)
        XCTAssertEqual(model.batches.map(\.kind), [.due, .difficult, .firstReview])
        XCTAssertEqual(model.batches.flatMap(\.items).map(\.savedID), ["due", "hard", "first"])
        XCTAssertEqual(model.batches.map(\.session.origin), [.due, .difficult, .due])
        XCTAssertTrue(model.batches.allSatisfy { $0.session.backTitle == "Back to daily study plan" })
    }
    func testDifficultTiesPrioritizeTheLatestMiss() {
        let older = item("a"), newer = item("z")
        func record(_ item: ReviewItem, date: Double) -> DifficultyRecord {
            .init(id: item.compositeID, missCount: 2, lastMissDate: Date(timeIntervalSince1970: date), lastSessionID: UUID(), sessionHadAgain: true, lastActionID: UUID())
        }
        let model = DailyStudyPlanViewModel(load: {
            .init(items: [older, newer], reviews: [], difficulties: [record(older, date: 100), record(newer, date: 200)], completed: [], target: nil)
        }, now: { self.now })
        model.send(.load)
        XCTAssertEqual(model.batches.first?.items.map(\.savedID), ["z", "a"])
    }
    func testRemainingGoalCapsBatchAndGoalMetPracticeIsOptional() {
        let items = (0..<15).map { item(String($0)) }
        var snapshot = DailyStudyPlanViewModel.Snapshot(items: items, reviews: [], difficulties: [], completed: [item("other").compositeID], target: 5)
        let model = DailyStudyPlanViewModel(load: { snapshot }, now: { self.now })
        model.send(.load)
        XCTAssertEqual(model.batches.flatMap(\.items).count, 4)
        snapshot.target = 1
        model.send(.load)
        XCTAssertTrue(model.goalReached)
        XCTAssertEqual(model.batches.flatMap(\.items).count, 10)
    }
    func testFailureClearsStaleBatchesAndRetryReloads() {
        enum Failure: Error { case read }
        var fail = false
        let model = DailyStudyPlanViewModel(load: {
            if fail { throw Failure.read }
            return .init(items: [self.item("first")], reviews: [], difficulties: [], completed: [], target: nil)
        }, now: { self.now })
        model.send(.load)
        XCTAssertEqual(model.batches.count, 1)
        fail = true; model.send(.load)
        XCTAssertNotNil(model.state.error)
        XCTAssertTrue(model.batches.isEmpty)
        fail = false; model.send(.load)
        XCTAssertNil(model.state.error)
        XCTAssertEqual(model.batches.count, 1)
    }
}
