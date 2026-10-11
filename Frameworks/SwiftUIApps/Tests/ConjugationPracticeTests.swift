import XCTest
import DataKit
@testable import SwiftUIApps

@MainActor
final class ConjugationPracticeTests: XCTestCase {
    private func model(save: @escaping (ExerciseCheckpoint) throws -> Void = { _ in }) -> ConjugationSetupViewModel {
        .init(load: AppliedPracticeCatalogRepository.bundled, save: save)
    }
    func testStableIntersectionLimitAndEmptySelection() {
        let model = model(); model.send(.load)
        XCTAssertNil(model.state.error)
        XCTAssertEqual(model.selected.count, 5)
        XCTAssertEqual(model.candidates.map(\.id), model.candidates.map(\.id).sorted())
        model.send(.classID("ichidan")); model.send(.formID("te")); model.send(.limit(nil))
        XCTAssertFalse(model.selected.isEmpty)
        XCTAssertTrue(model.selected.allSatisfy { $0.metadata?.topicID == "form:ichidan:te" })
        model.send(.classID("naAdjective"))
        XCTAssertTrue(model.selected.isEmpty)
        model.send(.start); XCTAssertNil(model.state.startedKey)
    }
    func testExplicitStartCapturesSelectedSnapshotsAndSaveFailureCanRetry() {
        enum Failure: Error { case save }
        var saved: [ExerciseCheckpoint] = []; var fails = true
        let model = model { checkpoint in
            saved.append(checkpoint)
            if fails { throw Failure.save }
        }
        model.send(.load); XCTAssertTrue(saved.isEmpty)
        model.send(.limit(10)); model.send(.start)
        XCTAssertNotNil(model.state.startError); XCTAssertNil(model.state.startedKey)
        fails = false; model.send(.start)
        XCTAssertNil(model.state.startError)
        XCTAssertEqual(saved.last?.orderedSnapshots, model.selected)
        XCTAssertEqual(saved.last?.orderedSnapshots.count, 10)
        XCTAssertEqual(saved.last?.activityKey, model.state.startedKey)
    }
    func testTopicAndExactLemmaRestrictions() {
        let model = ConjugationSetupViewModel(topicID: "form:godan:te", lemma: "行く", load: AppliedPracticeCatalogRepository.bundled, save: { _ in })
        model.send(.load)
        XCTAssertEqual(model.selected.count, 1)
        XCTAssertEqual(model.selected.first?.metadata?.stimulus, "行く")
        let absent = ConjugationSetupViewModel(lemma: "invented", load: AppliedPracticeCatalogRepository.bundled, save: { _ in })
        absent.send(.load); XCTAssertTrue(absent.selected.isEmpty)
    }
    func testReturningToSetupCanStartWithUnchangedFilters() {
        var saved: [ExerciseCheckpoint] = []
        let model = model { saved.append($0) }
        model.send(.load); model.send(.start)
        let key = model.state.startedKey
        model.send(.load)
        XCTAssertNil(model.state.startedKey)
        model.send(.start)
        XCTAssertEqual(model.state.startedKey, key)
        XCTAssertEqual(saved.count, 2)
        XCTAssertNotEqual(saved[0].sessionID, saved[1].sessionID)
    }
    func testListeningMistakesRetainPlaybackRequirement() {
        let snapshot = ExerciseSnapshot(id: "listening:test", revision: 1, questionKind: .listeningReading, prompt: "切手", acceptedAnswers: ["きって"], explanation: "Reading")
        XCTAssertTrue(ExerciseResumePolicy.requiresListening(activityKey: "mistakes:test", snapshots: [snapshot]))
        XCTAssertFalse(ExerciseResumePolicy.requiresListening(activityKey: "mistakes:test", snapshots: []))
    }
    func testLoadFailureNamesNextAction() {
        enum Failure: Error { case load }
        let model = ConjugationSetupViewModel(load: { throw Failure.load }, save: { _ in XCTFail("Must not save") })
        model.send(.load); XCTAssertFalse(model.state.isLoading); XCTAssertNotNil(model.state.error)
        model.send(.start); XCTAssertNil(model.state.startedKey)
    }
}
