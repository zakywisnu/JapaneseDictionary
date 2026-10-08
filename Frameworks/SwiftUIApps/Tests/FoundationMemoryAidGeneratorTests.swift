import XCTest
import FoundationModels
import DomainKit
@testable import SwiftUIApps

@MainActor
final class FoundationMemoryAidGeneratorTests: XCTestCase {
    func testSystemRefusalsAndMalformedResponsesKeepTheirDistinctFailureStates() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("New framework error types require iOS 27") }
        XCTAssertEqual(FoundationMemoryAidGenerator.generationError(for: LanguageModelError.guardrailViolation(.init(debugDescription: "guardrail"))), .refused)
        XCTAssertEqual(FoundationMemoryAidGenerator.generationError(for: LanguageModelError.refusal(.init(explanation: "refused", debugDescription: "refusal"))), .refused)
        XCTAssertEqual(FoundationMemoryAidGenerator.generationError(for: GeneratedContent.ParsingError(rawContent: "broken", debugDescription: "invalid response")), .invalidResponse)
    }

    func testOlderFrameworkFailuresAndUnknownServiceErrorsAreHandled() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("FoundationModels requires iOS 26") }
        XCTAssertEqual(FoundationMemoryAidGenerator.generationError(for: LanguageModelSession.GenerationError.guardrailViolation(.init(debugDescription: "guardrail"))), .refused)
        XCTAssertEqual(FoundationMemoryAidGenerator.generationError(for: LanguageModelSession.GenerationError.decodingFailure(.init(debugDescription: "invalid"))), .invalidResponse)
        XCTAssertEqual(FoundationMemoryAidGenerator.generationError(for: NSError(domain: "ModelManagerServices", code: 1008)), .failed)
    }
}
