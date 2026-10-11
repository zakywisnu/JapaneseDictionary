import XCTest
@testable import DataKit

final class AppliedPracticeHistoryTests: XCTestCase {
    func testOldSnapshotFingerprintIsUnchanged() throws {
        let bytes = Data(#"{"id":"legacy-choice","revision":1,"fingerprint":"93362499e69f710c66d34b8718c433ed39512f730bba8819232f25de8179d6b8","questionKind":"choice","prompt":"Choose","choices":["A","B"],"correctIndex":0,"acceptedAnswers":[],"explanation":"A is correct"}"#.utf8)
        let old = try JSONDecoder().decode(ExerciseSnapshot.self, from: bytes)
        XCTAssertNil(old.metadata)
        XCTAssertEqual(old.fingerprint, old.computedFingerprint)
        try ExerciseHistoryValidator.validateSnapshot(old)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(old), as: UTF8.self).contains("metadata"))
    }
    private func sentence(orders: [[String]] = [["a", "b", "c"]], assisted: Bool = false) -> ExerciseSnapshot {
        .init(id: "sentence", revision: 1, questionKind: .sentenceOrder, prompt: "Arrange", explanation: "Explanation", metadata: .init(activityKind: "sentenceOrder", topicID: "topic", tokens: [.init(id: "a", text: "も"), .init(id: "b", text: "も"), .init(id: "c", text: "ある")], acceptedOrders: orders, source: "Original", assisted: assisted))
    }
    func testRepeatedTokensAcceptEquivalentRenderingAndRoundtrip() throws {
        let snapshot = sentence()
        let value = ExerciseAttempt(sessionID: UUID(), snapshot: snapshot, response: .orderedTokens(["b", "a", "c"]), outcome: .correct, submittedAt: Date())
        try ExerciseHistoryValidator.validateAttempt(value)
        XCTAssertEqual(try JSONDecoder().decode(ExerciseAttempt.self, from: JSONEncoder().encode(value)), value)
    }
    func testMalformedPermutationAndAssistedAttemptsFail() {
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateSnapshot(sentence(orders: [["a", "a", "c"]])))
        let invalid = ExerciseAttempt(sessionID: UUID(), snapshot: sentence(), response: .orderedTokens(["a", "a", "c"]), outcome: .correct, submittedAt: Date())
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateAttempt(invalid))
        let assisted = ExerciseAttempt(sessionID: UUID(), snapshot: sentence(assisted: true), response: .orderedTokens(["a", "b", "c"]), outcome: .correct, submittedAt: Date())
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateAttempt(assisted))
    }
    func testFutureMetadataAndIncorrectOutcomeFail() {
        var snapshot = sentence(); snapshot.metadata?.schemaVersion = 2; snapshot.fingerprint = snapshot.computedFingerprint
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateSnapshot(snapshot))
        let wrong = ExerciseAttempt(sessionID: UUID(), snapshot: sentence(), response: .orderedTokens(["c", "b", "a"]), outcome: .correct, submittedAt: Date())
        XCTAssertThrowsError(try ExerciseHistoryValidator.validateAttempt(wrong))
    }
    func testConjugationPreservesKanaDistinctions() {
        XCTAssertTrue(ExerciseAnswerNormalizer.matches(" カイタ ", accepted: ["かいた"], kind: .conjugation))
        XCTAssertFalse(ExerciseAnswerNormalizer.matches("きて", accepted: ["きって"], kind: .conjugation))
        XCTAssertFalse(ExerciseAnswerNormalizer.matches("こう", accepted: ["こお"], kind: .conjugation))
    }
}
