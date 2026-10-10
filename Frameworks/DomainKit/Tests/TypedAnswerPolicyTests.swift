import XCTest
import DataKit
@testable import DomainKit

final class TypedAnswerPolicyTests: XCTestCase {
    func testKanaCompositionWidthAndConfiguredScriptEquivalence() {
        for input in ["ガ", "ｶﾞ", "か\u{3099}", "  が\n"] {
            XCTAssertEqual(TypedAnswerPolicy.evaluate(input: input, accepted: ["が"], mode: .kanaReading), .match)
        }
        XCTAssertEqual(TypedAnswerPolicy.evaluate(input: "キッテ", accepted: ["きって"], mode: .kanaReading), .match)
    }
    func testSmallKanaVoicingAndVowelLengthStayDistinct() {
        for pair in [("きて", "きって"), ("おばさん", "おばあさん"), ("か", "が"), ("きや", "きゃ"), ("コヒ", "コーヒー")] {
            XCTAssertEqual(TypedAnswerPolicy.evaluate(input: pair.0, accepted: [pair.1], mode: .kanaReading), .different)
        }
    }
    func testAliasesBelongToExactKanaEntry() throws {
        let shi = try XCTUnwrap(KanaCatalog.entries.first { $0.kana == "し" })
        let ka = try XCTUnwrap(KanaCatalog.entries.first { $0.kana == "か" })
        XCTAssertEqual(TypedAnswerPolicy.evaluate(input: " SI ", accepted: TypedAnswerPolicy.romanizationAliases(for: shi), mode: .romanization), .match)
        XCTAssertEqual(TypedAnswerPolicy.evaluate(input: "si", accepted: TypedAnswerPolicy.romanizationAliases(for: ka), mode: .romanization), .different)
        XCTAssertEqual(TypedAnswerPolicy.evaluate(input: "see", accepted: TypedAnswerPolicy.romanizationAliases(for: shi), mode: .romanization), .different)
    }
    func testEmptyAndBoundedInput() {
        XCTAssertEqual(TypedAnswerPolicy.evaluate(input: " \n", accepted: ["a"], mode: .romanization), .empty)
        XCTAssertEqual(TypedAnswerPolicy.evaluate(input: String(repeating: "a", count: 501), accepted: [String(repeating: "a", count: 501)], mode: .romanization), .different)
    }
}
