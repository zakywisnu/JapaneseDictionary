import Foundation
import Observation
import DataKit
import DomainKit

@MainActor
@Observable
public final class MemoryAidViewModel {
    struct State {
        var availability: MemoryAidAvailability
        var suggestion: MemoryAidSuggestion?
        var persistedSuggestion: MemoryAidSuggestion?
        var isGenerating = false
        var loadError: String?
        var generationError: String?
        var saveError: String?

        var isSaved: Bool { suggestion != nil && suggestion == persistedSuggestion }
        var canGenerate: Bool { availability == .available && !isGenerating && loadError == nil }
    }

    enum Action { case load, refreshAvailability, generate, save, cancel }

    private(set) var state: State
    private let word: MemoryAidWord
    private let repository: any MemoryAidRepository
    private let generator: any MemoryAidGenerating
    private var requestID: UUID?
    private var generationTask: Task<Void, Never>?

    public init(word: MemoryAidWord, repository: any MemoryAidRepository, generator: any MemoryAidGenerating) {
        self.word = word
        self.repository = repository
        self.generator = generator
        state = .init(availability: generator.availability)
    }

    func send(_ action: Action) async {
        switch action {
        case .load:
            state.availability = generator.availability
            do {
                let persisted = try repository.load(for: word)
                let shouldReplace = state.suggestion == nil || state.isSaved
                state.persistedSuggestion = persisted
                if shouldReplace { state.suggestion = persisted }
                state.loadError = nil
            } catch {
                state.loadError = "The saved suggestion for \(word.headword) couldn't be opened. Try loading it again."
            }
        case .refreshAvailability:
            state.availability = generator.availability
        case .generate:
            state.availability = generator.availability
            guard state.canGenerate else { return }
            let id = UUID()
            requestID = id
            state.isGenerating = true
            state.generationError = nil
            state.saveError = nil
            let task = Task { [self] in
                do {
                    let result = try await generator.generate(for: word)
                    guard requestID == id, !Task.isCancelled else { return }
                    state.suggestion = result
                } catch {
                    guard requestID == id, !Task.isCancelled else { return }
                    if !(error is CancellationError) {
                        state.generationError = generationMessage(for: error)
                    }
                }
                guard requestID == id else { return }
                state.isGenerating = false
                state.availability = generator.availability
                requestID = nil
                generationTask = nil
            }
            generationTask = task
            await task.value
        case .save:
            guard let suggestion = state.suggestion, !state.isGenerating, !state.isSaved else { return }
            do {
                try repository.save(suggestion, for: word)
                state.persistedSuggestion = suggestion
                state.saveError = nil
            } catch {
                state.saveError = "The suggestion for \(word.headword) couldn't be saved. Try saving again. If the word was removed or restored, reopen it from your collection."
            }
        case .cancel:
            cancel()
        }
    }

    func cancel() {
        // Invalidate before cancelling: a generator may finish despite cancellation.
        requestID = nil
        generationTask?.cancel()
        generationTask = nil
        state.isGenerating = false
    }

    private func generationMessage(for error: Error) -> String {
        switch error as? MemoryAidGenerationError {
        case .refused:
            return "A suggestion for \(word.headword) couldn't be provided. Try again, or use the meanings above."
        case .invalidResponse:
            return "The suggestion for \(word.headword) was incomplete. Try generating it again."
        case .invalidInput:
            return "This word's study details couldn't be used. Reopen \(word.headword) from your collection and try again."
        default:
            return "A suggestion for \(word.headword) couldn't be generated. Try generating again, or use the meanings above."
        }
    }
}
