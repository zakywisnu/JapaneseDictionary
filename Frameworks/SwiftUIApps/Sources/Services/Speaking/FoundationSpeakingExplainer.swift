import DomainKit
import Foundation
import FoundationModels

@MainActor
enum SpeakingExplainerFactory {
    static func make() -> any SpeakingFeedbackGenerating {
        if #available(iOS 26.0, *) { return FoundationSpeakingExplainer() }
        return UnavailableSpeakingExplainer()
    }
}

@MainActor
private struct UnavailableSpeakingExplainer: SpeakingFeedbackGenerating {
    var availability: MemoryAidAvailability { .requiresNewerOS }
    func generate(target: SpeakingTarget, evidence: SpeechRecognitionEvidence, comparison: SpeakingComparisonResult) async throws -> SpeakingFeedback { throw SpeakingFeedbackError.unavailable }
}

@available(iOS 26.0, *)
@MainActor
final class FoundationSpeakingExplainer: SpeakingFeedbackGenerating {
    private let model = SystemLanguageModel.default
    var availability: MemoryAidAvailability {
        switch model.availability {
        case .available: return model.supportsLocale(Locale(identifier: "ja")) && model.supportsLocale(Locale(identifier: "en")) ? .available : .unsupportedLanguage
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .unavailable
            }
        }
    }
    func generate(target: SpeakingTarget, evidence: SpeechRecognitionEvidence, comparison: SpeakingComparisonResult) async throws -> SpeakingFeedback {
        try Task.checkCancellation()
        guard availability == .available else { throw SpeakingFeedbackError.unavailable }
        let prompt = try SpeakingFeedbackPrompt.request(target: target, evidence: evidence, comparison: comparison)
        let session = LanguageModelSession(model: model, instructions: SpeakingFeedbackPrompt.instructions)
        do {
            let response = try await session.respond(to: prompt, generating: Draft.self, options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 512))
            try Task.checkCancellation()
            return try SpeakingFeedback.grounded(explanationKind: response.content.explanationKind, practiceTipKind: response.content.practiceTipKind, comparison: comparison)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            if let known = error as? SpeakingFeedbackError { throw known }
            switch FoundationMemoryAidGenerator.generationError(for: error) {
            case .refused: throw SpeakingFeedbackError.refused
            case .invalidResponse: throw SpeakingFeedbackError.invalidResponse
            default: throw SpeakingFeedbackError.failed
            }
        }
    }
    @Generable
    struct Draft {
        @Guide(description: "Exactly the supplied comparison outcome: match, different, or inconclusive.")
        var explanationKind: String
        @Guide(description: "One identifier only: listen_then_replay, record_again, or compare_written_text.")
        var practiceTipKind: String
    }
}
