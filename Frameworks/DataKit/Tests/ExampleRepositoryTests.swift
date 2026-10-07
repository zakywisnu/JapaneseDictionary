import XCTest
@testable import DataKit

final class ExampleRepositoryTests: XCTestCase {
    func testEmptyApprovedBundleReturnsNoExample() throws {
        let repository = try ExampleRepository(data: fixture(examples: []))
        XCTAssertNil(repository.example(for: .init(headword: "猫", reading: "ねこ", level: "N5")))
    }

    func testMalformedAndUnsupportedBundlesThrow() {
        XCTAssertThrowsError(try ExampleRepository(data: Data("not JSON".utf8)))
        XCTAssertThrowsError(try ExampleRepository(data: fixture(examples: [], version: 2)))
    }

    func testDuplicateWordKeysThrow() {
        XCTAssertThrowsError(try ExampleRepository(data: fixture(examples: [example(), example()])))
    }

    func testExactWordKeyAndNullableAttributionArePreserved() throws {
        let repository = try ExampleRepository(data: fixture(examples: [example()]))
        let key = ExampleWordKey(headword: "猫", reading: "ねこ", level: "N5")
        let result = try XCTUnwrap(repository.example(for: key))
        XCTAssertEqual(result.japanese, "猫です。")
        XCTAssertNil(result.japaneseOwner)
        XCTAssertNil(result.sentenceReading)
        XCTAssertNil(repository.example(for: .init(headword: "猫", reading: "ネコ", level: "N5")))
    }

    func testMissingReviewAndChangedSourceTextAreRejected() {
        var missing = example()
        missing.removeValue(forKey: "review")
        XCTAssertThrowsError(try ExampleRepository(data: fixture(examples: [missing])))
        var changed = example()
        changed["japanese"] = "犬です。"
        XCTAssertThrowsError(try ExampleRepository(data: fixture(examples: [changed])))
        var invalid = example()
        invalid["license"] = "unknown"
        XCTAssertThrowsError(try ExampleRepository(data: fixture(examples: [invalid])))
    }

    private func fixture(examples: [[String: Any]], version: Int = 1) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "formatVersion": version,
            "sourceSnapshot": ["downloadedOn": "2026-10-06", "sources": [], "vocabularySha256": String(repeating: "a", count: 64)],
            "examples": examples
        ])
    }

    private func example() -> [String: Any] {
        ["word": ["headword": "猫", "reading": "ねこ", "level": "N5"],
         "japaneseId": "1", "englishId": "2", "japanese": "猫です。", "english": "It is a cat.",
         "japaneseSource": "https://tatoeba.org/en/sentences/show/1",
         "englishSource": "https://tatoeba.org/en/sentences/show/2",
         "japaneseOwner": NSNull(), "englishOwner": "fixture", "sentenceReading": NSNull(),
         "license": "CC BY 2.0 FR", "review": [
            "reviewer": "human fixture", "reviewedOn": "2026-10-06", "verifiedSense": "cat noun fixture",
            "japaneseSha256": "61e295130a0dbe27b492f94775c9b835409aed4a0bfe6d76c1c66ec0feed0461",
            "englishSha256": "752c660c7793c4f440f19dc7331ed5afaae006f2378c373c931f727de4b80be1",
            "changes": []]]
    }
}
