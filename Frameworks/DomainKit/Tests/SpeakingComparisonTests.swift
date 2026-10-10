import XCTest
@testable import DomainKit

final class SpeakingComparisonTests: XCTestCase {
    private func compare(_ reading: String, _ transcript: String, final: Bool = true, prompt: String? = nil) -> SpeakingComparisonResult {
        SpeakingComparison.compare(target: .init(id: "test", prompt: prompt ?? reading, suppliedReading: reading), evidence: .init(transcript: transcript, isFinal: final))
    }
    func testPunctuationSpacingAndScriptAreKnownEquivalents() {
        XCTAssertEqual(compare("ねこ、です。", "ネコ です").outcome, .match)
    }
    func testEmptyPartialAndIsolatedSoundsAreInconclusive() {
        XCTAssertEqual(compare("ねこ", "").outcome, .inconclusive)
        XCTAssertEqual(compare("ねこ", "ねこ", final: false).outcome, .inconclusive)
        XCTAssertEqual(compare("あ", "あ").outcome, .inconclusive)
    }
    func testVowelLengthVoicingAndSmallKanaRemainDistinct() {
        for pair in [("おばさん", "おばあさん"), ("きて", "きって"), ("きゃく", "きやく"), ("かっこう", "がっこう"), ("コーヒー", "コヒ")] {
            XCTAssertEqual(compare(pair.0, pair.1).outcome, .different)
        }
    }
    func testUnknownWrittenAlignmentIsInconclusiveAndExactPromptMatches() {
        XCTAssertEqual(compare("はし", "橋", prompt: "箸").outcome, .inconclusive)
        let result = compare("はし", "箸", prompt: "箸")
        XCTAssertEqual(result.outcome, .match)
        XCTAssertTrue(result.reason.contains("Homophones"))
    }
}
