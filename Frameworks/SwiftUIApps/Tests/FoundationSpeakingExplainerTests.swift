import DomainKit
import XCTest
@testable import SwiftUIApps

@MainActor
final class FoundationSpeakingExplainerTests: XCTestCase {
    func testFactoryPreservesUnavailableOSFallback() async {
        let service = SpeakingExplainerFactory.make()
        if #available(iOS 26.0, *) {
            XCTAssertTrue([MemoryAidAvailability.available, .deviceNotEligible, .notEnabled, .modelNotReady, .unsupportedLanguage, .unavailable].contains(service.availability))
        } else {
            XCTAssertEqual(service.availability, .requiresNewerOS)
            let target = SpeakingTarget(id: "t", prompt: "ねこ", suppliedReading: "ねこ")
            let evidence = SpeechRecognitionEvidence(transcript: "ねこ", isFinal: true)
            do {
                _ = try await service.generate(target: target, evidence: evidence, comparison: SpeakingComparison.compare(target: target, evidence: evidence))
                XCTFail("Unavailable OS started generation")
            } catch {}
        }
    }
}
