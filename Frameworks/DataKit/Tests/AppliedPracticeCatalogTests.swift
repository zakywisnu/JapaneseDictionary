import XCTest
@testable import DataKit

final class AppliedPracticeCatalogTests: XCTestCase {
    private func catalog() -> AppliedPracticeCatalog {
        let metadata = PracticeMetadata(activityKind: "conjugation", topicID: "godan", source: "Original teaching example")
        var question = ExerciseSnapshot(id: "write-past", revision: 1, questionKind: .conjugation, prompt: "書く past", acceptedAnswers: ["書いた", "かいた"], explanation: "く becomes いた", metadata: metadata)
        let reviewHash = question.computedReviewHash
        question.metadata?.review = .init(reviewer: "Model reviewer", date: "2026-10-11", contentHash: reviewHash, method: "model-based content check; no human review")
        question.fingerprint = question.computedFingerprint
        return .init(activities: [.init(id: "godan-past", title: "Past", kind: .conjugation, questions: [question])], contexts: [])
    }
    func testReviewedCatalogRoundtrip() throws {
        let value = catalog()
        XCTAssertEqual(try AppliedPracticeCatalogRepository(data: JSONEncoder().encode(value)).catalog, value)
    }
    func testAnswerChangesRequireReviewButAssistanceDoesNotAlterAuthoredHash() throws {
        let original = catalog().activities[0].questions[0]
        var assisted = original; assisted.metadata?.assisted = true; assisted.fingerprint = assisted.computedFingerprint
        XCTAssertEqual(original.computedReviewHash, assisted.computedReviewHash)
        try ExerciseHistoryValidator.validateSnapshot(assisted)
        var changed = original; changed.acceptedAnswers = ["かいて"]; changed.fingerprint = changed.computedFingerprint
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateSnapshot(changed))
    }
    func testMissingReviewChangedContentAndDuplicateIDsFail() {
        var value = catalog(); value.activities[0].questions[0].metadata?.review = nil
        value.activities[0].questions[0].fingerprint = value.activities[0].questions[0].computedFingerprint
        XCTAssertThrowsError(try AppliedPracticeCatalogRepository.validate(value))
        value = catalog(); value.activities[0].questions[0].metadata?.source = "Changed"
        value.activities[0].questions[0].fingerprint = value.activities[0].questions[0].computedFingerprint
        XCTAssertThrowsError(try AppliedPracticeCatalogRepository.validate(value))
        value = catalog(); value.activities.append(value.activities[0])
        XCTAssertThrowsError(try AppliedPracticeCatalogRepository.validate(value))
    }
}
