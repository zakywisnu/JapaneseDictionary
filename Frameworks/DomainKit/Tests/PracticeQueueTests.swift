import XCTest
@testable import DomainKit

final class PracticeQueueTests: XCTestCase {
    func testAgainReturnsAfterOtherItems() {
        var queue = PracticeQueue(ids: ["a", "b"])
        queue.rate(.again)
        XCTAssertEqual(queue.currentID, "b")
        XCTAssertEqual(queue.remainingCount, 2)
        queue.rate(.gotIt)
        XCTAssertEqual(queue.currentID, "a")
        XCTAssertEqual(queue.repeatAttempts, 1)
        queue.rate(.gotIt)
        XCTAssertNil(queue.currentID)
        XCTAssertEqual(queue.remainingCount, 0)
    }

    func testOneMissedItemRemainsAvailable() {
        var queue = PracticeQueue(ids: ["a"])
        queue.rate(.again)
        queue.rate(.again)
        XCTAssertEqual(queue.currentID, "a")
        XCTAssertEqual(queue.repeatAttempts, 2)
        queue.rate(.gotIt)
        XCTAssertNil(queue.currentID)
    }

    func testDuplicateIDsPracticeEachDistinctItemOnce() {
        var queue = PracticeQueue(ids: ["a", "b", "a", "b", "c"])
        XCTAssertEqual(queue.remainingCount, 3)
        queue.rate(.gotIt)
        XCTAssertEqual(queue.currentID, "b")
        queue.rate(.gotIt)
        XCTAssertEqual(queue.currentID, "c")
        queue.rate(.gotIt)
        XCTAssertNil(queue.currentID)
    }

    func testEmptyQueueIgnoresRatings() {
        var queue = PracticeQueue(ids: [])
        queue.rate(.again)
        queue.rate(.gotIt)
        XCTAssertNil(queue.currentID)
        XCTAssertEqual(queue.remainingCount, 0)
        XCTAssertEqual(queue.repeatAttempts, 0)
    }
}
