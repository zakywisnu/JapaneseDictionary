import XCTest
import DataKit
@testable import DomainKit

final class ContextReviewTests: XCTestCase {
    private let key = ExampleWordKey(headword: "青い", reading: "あおい", level: "N5")
    private func entry(id: String = "blue", meanings: [String] = ["blue"], key: ExampleWordKey? = nil) -> ReviewedContext {
        .init(stableID: id, word: key ?? self.key, verifiedMeanings: meanings, cloze: "空は＿＿です。", japanese: "空は青いです。", reading: "そらはあおいです。", translation: "The sky is blue.", source: "Original model-checked practice")
    }
    func testExactSelectedMeaningAndReadingAreRequired() {
        let useCase = ContextReviewUseCase(contexts: [entry()])
        XCTAssertEqual(useCase.context(for: key, savedMeanings: [" Blue "])?.stableID, "blue")
        XCTAssertNil(useCase.context(for: key, savedMeanings: ["learner's unrelated meaning"]))
        XCTAssertNil(useCase.context(for: .init(headword: "青い", reading: "せい", level: "N5"), savedMeanings: ["blue"]))
        XCTAssertNil(useCase.context(for: key, savedMeanings: ["blue", "green"]))
    }
    func testHomographSelectionAndAmbiguityFallback() {
        let useCase = ContextReviewUseCase(contexts: [entry(), entry(id: "pale", meanings: ["pale"])])
        XCTAssertEqual(useCase.context(for: key, savedMeanings: ["pale"])?.stableID, "pale")
        XCTAssertNil(ContextReviewUseCase(contexts: [entry(), entry(id: "duplicate")]).context(for: key, savedMeanings: ["blue"]))
        XCTAssertNil(ContextReviewUseCase(contexts: []).context(for: key, savedMeanings: ["blue"]))
    }
}
