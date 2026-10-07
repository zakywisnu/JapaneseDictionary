import Foundation
import FoundationModels
import DomainKit
import DataKit

@MainActor
enum MemoryAidGeneratorFactory {
    static func make() -> any MemoryAidGenerating {
        if #available(iOS 26.0, *) { return FoundationMemoryAidGenerator() }
        return UnavailableMemoryAidGenerator()
    }
}

@MainActor
private struct UnavailableMemoryAidGenerator: MemoryAidGenerating {
    var availability: MemoryAidAvailability { .requiresNewerOS }
    func generate(for word: MemoryAidWord) async throws -> MemoryAidSuggestion {
        throw MemoryAidGenerationError.failed
    }
}

@available(iOS 26.0, *)
@MainActor
final class FoundationMemoryAidGenerator: MemoryAidGenerating {
    private let model = SystemLanguageModel.default

    var availability: MemoryAidAvailability {
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "ja")) && model.supportsLocale(Locale(identifier: "en")) ? .available : .unsupportedLanguage
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .unavailable
            }
        }
    }

    func generate(for word: MemoryAidWord) async throws -> MemoryAidSuggestion {
        try Task.checkCancellation()
        guard availability == .available else { throw MemoryAidGenerationError.failed }
        let prompt = try MemoryAidPrompt.request(for: word)
        let session = LanguageModelSession(model: model, instructions: MemoryAidPrompt.instructions)
        do {
            let response = try await session.respond(to: prompt, generating: Draft.self,
                options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 512))
            try Task.checkCancellation()
            do { return try MemoryAidSuggestion(explanation: response.content.explanation, mnemonic: response.content.mnemonic).validated() }
            catch { throw MemoryAidGenerationError.invalidResponse }
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw Self.generationError(for: error)
        }
    }

    static func generationError(for error: Error) -> MemoryAidGenerationError {
        if let known = error as? MemoryAidGenerationError { return known }
        if #available(iOS 27.0, *) {
            if error is GeneratedContent.ParsingError { return .invalidResponse }
            if let generation = error as? LanguageModelError {
                switch generation {
                case .guardrailViolation, .refusal: return .refused
                default: break
                }
            }
        }
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .guardrailViolation, .refusal: return .refused
            case .decodingFailure: return .invalidResponse
            default: break
            }
        }
        return .failed
    }

    @Generable
    struct Draft {
        @Guide(description: "One or two short English sentences explaining only the supplied meanings, at most 600 characters.")
        var explanation: String
        @Guide(description: "A short playful memory association in English, at most 600 characters. Not a historical origin or dictionary fact.")
        var mnemonic: String
    }
}
