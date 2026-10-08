import XCTest
import DomainKit
@testable import SwiftUIApps

final class DailyGoalPresentationTests: XCTestCase {
    func testSummaryDefaultsAndReloadUsesCurrentDate() {
        let stub = GoalUseCaseStub()
        var date = Date(timeIntervalSince1970: 1)
        let model = DailyGoalViewModel(getDailyGoal: stub, now: { date })
        XCTAssertTrue(model.state.isLoading)
        model.send(.load)
        XCTAssertEqual(model.state.summary?.target, 10)
        date = Date(timeIntervalSince1970: 2)
        stub.summary = .init(target: 5, completedCount: 7)
        model.send(.load)
        XCTAssertEqual(stub.dates, [Date(timeIntervalSince1970: 1), date])
        XCTAssertTrue(model.state.summary?.isReached == true)
    }

    func testOffKeepsActivityAndLoadingFailureCanRetry() {
        let stub = GoalUseCaseStub()
        stub.summary = .init(target: nil, completedCount: 4)
        let model = DailyGoalViewModel(getDailyGoal: stub)
        model.send(.load)
        XCTAssertFalse(model.state.isSummaryVisible)
        XCTAssertEqual(model.state.summary?.completedCount, 4)
        stub.fail = true
        model.send(.load)
        XCTAssertNotNil(model.state.error)
        stub.fail = false
        model.send(.load)
        XCTAssertNil(model.state.error)
        XCTAssertFalse(model.state.isLoading)
    }

    func testFailedSavePreservesChoiceAndCancelDoesNotSave() {
        let stub = GoalUseCaseStub()
        let model = DailyGoalViewModel(getDailyGoal: stub, setDailyGoal: stub)
        model.send(.load)
        model.send(.selectTarget(20))
        stub.fail = true
        model.send(.save)
        XCTAssertEqual(model.state.selectedTarget, 20)
        XCTAssertNotNil(model.state.saveError)
        XCTAssertFalse(model.state.didSave)
        model.send(.cancel)
        XCTAssertEqual(model.state.selectedTarget, 10)
        XCTAssertEqual(stub.savedTargets.count, 0)
    }

    func testRetrySavesPreservedChoice() {
        let stub = GoalUseCaseStub()
        let model = DailyGoalViewModel(getDailyGoal: stub, setDailyGoal: stub)
        model.send(.load)
        model.send(.selectTarget(30))
        stub.fail = true
        model.send(.save)
        stub.fail = false
        model.send(.save)
        XCTAssertEqual(stub.savedTargets, [30])
        XCTAssertTrue(model.state.didSave)
        XCTAssertNil(model.state.saveError)
    }

    func testAllowedChoicesSaveIncludingOffWithoutChangingActivity() {
        let stub = GoalUseCaseStub()
        stub.summary = .init(target: 10, completedCount: 3)
        let model = DailyGoalViewModel(getDailyGoal: stub, setDailyGoal: stub)
        model.send(.load)
        for target in [nil, 5, 10, 20, 30] as [Int?] {
            model.send(.selectTarget(target))
            model.send(.save)
            XCTAssertTrue(model.state.didSave)
            XCTAssertEqual(stub.savedTargets.last!, target)
            XCTAssertEqual(stub.summary.completedCount, 3)
        }
    }
}

private final class GoalUseCaseStub: GetDailyStudyGoalUseCase, SetDailyStudyGoalUseCase {
    var summary = DailyStudyGoalSummary(target: 10, completedCount: 0)
    var fail = false
    var dates: [Date] = []
    var savedTargets: [Int?] = []
    func execute(now: Date) throws -> DailyStudyGoalSummary {
        if fail { throw NSError(domain: "GoalTest", code: 1) }
        dates.append(now)
        return summary
    }
    func execute(target: Int?) throws {
        if fail { throw NSError(domain: "GoalTest", code: 1) }
        savedTargets.append(target)
        summary = .init(target: target, completedCount: summary.completedCount)
    }
}
