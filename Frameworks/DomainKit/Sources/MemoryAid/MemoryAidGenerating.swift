import Foundation
import DataKit

public enum MemoryAidAvailability: Equatable, Sendable {
    case available, requiresNewerOS, deviceNotEligible, notEnabled, modelNotReady, unsupportedLanguage, unavailable
}

public enum MemoryAidGenerationError: Error, Equatable {
    case invalidInput, refused, invalidResponse, failed
}

@MainActor
public protocol MemoryAidGenerating {
    var availability: MemoryAidAvailability { get }
    func generate(for word: MemoryAidWord) async throws -> MemoryAidSuggestion
}
