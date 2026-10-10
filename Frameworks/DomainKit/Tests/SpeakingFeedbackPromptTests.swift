import XCTest
@testable import DomainKit

final class SpeakingFeedbackPromptTests: XCTestCase {
    func testPromptBoundsAndResultGrounding() throws {
        let target = SpeakingTarget(id: "t", prompt: "ねこ", suppliedReading: "ねこ")
        let evidence = SpeechRecognitionEvidence(transcript: "ねこ", isFinal: true)
        let comparison = SpeakingComparison.compare(target: target, evidence: evidence)
        XCTAssertTrue(try SpeakingFeedbackPrompt.request(target: target, evidence: evidence, comparison: comparison).contains("recognized"))
        XCTAssertThrowsError(try SpeakingFeedbackPrompt.request(target: .init(id: "t", prompt: String(repeating: "あ", count: 501), suppliedReading: "ねこ"), evidence: evidence, comparison: comparison))
        XCTAssertThrowsError(try SpeakingFeedbackPrompt.request(target: target, evidence: .init(transcript: "", isFinal: true), comparison: comparison))
    }
    func testFeedbackRejectsUnsupportedAcousticClaimsAndOversizedFields() {
        for claim in ["Your pitch is perfect", "100% accurate", "Pronunciation is correct", "Good phonemes"] {
            XCTAssertThrowsError(try SpeakingFeedback(explanation: claim, practiceTip: "Replay the phrase.").validated())
        }
        XCTAssertThrowsError(try SpeakingFeedback(explanation: String(repeating: "a", count: 1001), practiceTip: "Replay.").validated())
        XCTAssertNoThrow(try SpeakingFeedback(explanation: "The transcript matches the supplied phrase.", practiceTip: "Listen, then replay your recording.").validated())
    }

    func testGroundedSelectionRejectsAcousticProseAndContradictoryOutcome() throws {
        let comparison = SpeakingComparisonResult(outcome: .different, expected: "きて", recognized: "きって", reason: "Transcript differs.")
        for claim in ["You omitted a mora.", "You shortened the long vowel.", "You pronounced the consonant incorrectly."] {
            XCTAssertThrowsError(try SpeakingFeedback.grounded(explanationKind: claim, practiceTipKind: "listen_then_replay", comparison: comparison))
            XCTAssertThrowsError(try SpeakingFeedback.grounded(explanationKind: "different", practiceTipKind: claim, comparison: comparison))
        }
        XCTAssertThrowsError(try SpeakingFeedback.grounded(explanationKind: "match", practiceTipKind: "listen_then_replay", comparison: comparison))
        let feedback = try SpeakingFeedback.grounded(explanationKind: "different", practiceTipKind: "listen_then_replay", comparison: comparison)
        XCTAssertTrue(feedback.explanation.contains("recognized kana text differs"))
        XCTAssertEqual(feedback.practiceTip, "Listen to the supplied reading, then replay your recording.")
    }

    func testEveryGroundedOutcomeAndPracticeTipProducesBoundedReviewedCopy() throws {
        for outcome in [SpeakingComparisonResult.Outcome.match, .different, .inconclusive] {
            let comparison = SpeakingComparisonResult(outcome: outcome, expected: "ねこ", recognized: "ねこ", reason: "You omitted a mora.")
            for tip in ["listen_then_replay", "record_again", "compare_written_text"] {
                let feedback = try SpeakingFeedback.grounded(explanationKind: outcome.rawValue, practiceTipKind: tip, comparison: comparison)
                XCTAssertNoThrow(try feedback.validated())
                XCTAssertFalse(feedback.explanation.contains("omitted a mora"))
            }
        }
    }
}
