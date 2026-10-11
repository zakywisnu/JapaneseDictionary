import XCTest
import DataKit
@testable import DomainKit

final class ConjugationPolicyTests: XCTestCase {
    func testExplicitExceptionsAndClassDifferences() {
        let cases: [(String, [String], String)] = [
            ("いって", ["行って", "いって"], "いで"),
            ("みた", ["見た", "みた"], "みった"),
            ("かえった", ["帰った", "かえった"], "かえた"),
            ("した", ["した"], "するた"),
            ("きた", ["来た", "きた"], "くるた"),
            ("ない", ["ない"], "あらない"),
            ("よかった", ["よかった"], "いかった"),
            ("しずかで", ["静かで", "しずかで"], "しずかて")
        ]
        for (correct, accepted, wrong) in cases {
            XCTAssertTrue(ConjugationPolicy.matches(correct, accepted: accepted))
            XCTAssertFalse(ConjugationPolicy.matches(wrong, accepted: accepted))
        }
        XCTAssertFalse(ConjugationPolicy.matches("いきます", accepted: ["行って", "いって"]))
    }
    func testNormalizationPreservesJapaneseDistinctions() {
        XCTAssertTrue(ConjugationPolicy.matches(" \n カイマス \t", accepted: ["かいます"]))
        XCTAssertTrue(ConjugationPolicy.matches("ｶｲﾏｽ", accepted: ["かいます"]))
        XCTAssertTrue(ConjugationPolicy.matches("およいて\u{3099}", accepted: ["およいで"]))
        XCTAssertFalse(ConjugationPolicy.matches("い って", accepted: ["いって"]))
        XCTAssertFalse(ConjugationPolicy.matches("いて", accepted: ["いって"]))
        XCTAssertFalse(ConjugationPolicy.matches("", accepted: [""]))
        XCTAssertFalse(ConjugationPolicy.matches(String(repeating: "あ", count: 501), accepted: [String(repeating: "あ", count: 501)]))
    }
    func testEveryBundledAnswerAndTargetIsExplicit() throws {
        let activities = try AppliedPracticeCatalogRepository.bundled().activities.filter { $0.kind == .conjugation }
        XCTAssertEqual(Set(activities.compactMap(\.classID)), Set(ConjugationPolicy.classes))
        XCTAssertEqual(Set(activities.compactMap(\.formID)), Set(ConjugationPolicy.forms))
        for question in activities.flatMap(\.questions) {
            XCTAssertFalse(question.acceptedAnswers.isEmpty)
            for answer in question.acceptedAnswers { XCTAssertTrue(ConjugationPolicy.matches(answer, accepted: question.acceptedAnswers)) }
        }
    }
}
