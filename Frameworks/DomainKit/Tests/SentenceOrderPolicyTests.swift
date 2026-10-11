import XCTest
import DataKit
@testable import DomainKit

final class SentenceOrderPolicyTests: XCTestCase {
    func testRepeatedTextUsesDistinctIDsButEquivalentOrdersMatch() {
        let tokens = [PracticeToken(id: "a", text: "の"), PracticeToken(id: "b", text: "の")]
        XCTAssertTrue(SentenceOrderPolicy.matches(["b", "a"], tokens: tokens, acceptedOrders: [["a", "b"]]))
        XCTAssertFalse(SentenceOrderPolicy.matches(["a", "a"], tokens: tokens, acceptedOrders: [["a", "b"]]))
    }
    func testAlternateOrdersAndMalformedPermutations() {
        let tokens = [PracticeToken(id: "a", text: "私"), PracticeToken(id: "b", text: "も")]
        XCTAssertTrue(SentenceOrderPolicy.matches(["b", "a"], tokens: tokens, acceptedOrders: [["a", "b"], ["b", "a"]]))
        XCTAssertFalse(SentenceOrderPolicy.matches(["a", "b"], tokens: tokens, acceptedOrders: [["a", "missing", "b"]]))
        XCTAssertFalse(SentenceOrderPolicy.matches(["a"], tokens: tokens, acceptedOrders: [["a"]]))
        XCTAssertFalse(SentenceOrderPolicy.matches(["a", "a"], tokens: [tokens[0], tokens[0]], acceptedOrders: [["a", "a"]]))
    }
}
