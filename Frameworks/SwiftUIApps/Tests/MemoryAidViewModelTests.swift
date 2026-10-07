import XCTest
import DataKit
import DomainKit
@testable import SwiftUIApps

final class MemoryAidViewModelTests: XCTestCase {
    @MainActor
    func testUnavailableLoadsSavedAdviceWithoutGenerating() async {
        let repository = MemoryAidTestRepository()
        repository.saved = suggestion
        let generator = MemoryAidTestGenerator()
        generator.availability = .notEnabled
        let model = makeModel(repository, generator)
        await model.send(.load)
        await model.send(.generate)
        XCTAssertEqual(model.state.suggestion, suggestion)
        XCTAssertTrue(model.state.isSaved)
        XCTAssertEqual(generator.requests, 0)
    }

    @MainActor
    func testDuplicateTapsGenerateOnceAndNeverAutosave() async {
        let repository = MemoryAidTestRepository()
        let generator = MemoryAidTestGenerator()
        let model = makeModel(repository, generator)
        await model.send(.load)
        let request = Task { await model.send(.generate) }
        await generator.waitUntilStarted()
        await model.send(.generate)
        XCTAssertEqual(generator.requests, 1)
        generator.finish(.success(suggestion))
        await request.value
        XCTAssertEqual(model.state.suggestion, suggestion)
        XCTAssertFalse(model.state.isSaved)
        XCTAssertEqual(repository.saves, 0)
    }

    @MainActor
    func testCancellationIgnoresLateResultAndAllowsAnotherRequest() async {
        let repository = MemoryAidTestRepository()
        let generator = MemoryAidTestGenerator()
        let model = makeModel(repository, generator)
        await model.send(.load)
        let request = Task { await model.send(.generate) }
        await generator.waitUntilStarted()
        await model.send(.cancel)
        XCTAssertFalse(model.state.isGenerating)
        generator.finish(.success(suggestion))
        await request.value
        XCTAssertNil(model.state.suggestion)
        let retry = Task { await model.send(.generate) }
        await generator.waitUntilStarted()
        generator.finish(.success(suggestion))
        await retry.value
        XCTAssertEqual(model.state.suggestion, suggestion)
        XCTAssertEqual(repository.saves, 0)
    }

    @MainActor
    func testCancelledRequestCannotOverwriteOrStopNewRequest() async {
        let repository = MemoryAidTestRepository()
        let generator = MemoryAidTestGenerator()
        let model = makeModel(repository, generator)
        await model.send(.load)
        let oldRequest = Task { await model.send(.generate) }
        await generator.waitUntilStarted()
        await model.send(.cancel)
        let newRequest = Task { await model.send(.generate) }
        await generator.waitUntilStarted(requestCount: 2)
        generator.finish(.success(suggestion))
        await oldRequest.value
        XCTAssertNil(model.state.suggestion)
        XCTAssertTrue(model.state.isGenerating)
        let newSuggestion = MemoryAidSuggestion(explanation: "A rule that guides a decision.", mnemonic: "Imagine a sign pointing to the rule.")
        generator.finish(.success(newSuggestion))
        await newRequest.value
        XCTAssertEqual(model.state.suggestion, newSuggestion)
        XCTAssertFalse(model.state.isGenerating)
    }

    @MainActor
    func testRegenerationFailurePreservesSavedSuggestion() async {
        let repository = MemoryAidTestRepository()
        repository.saved = suggestion
        let generator = MemoryAidTestGenerator()
        let model = makeModel(repository, generator)
        await model.send(.load)
        let request = Task { await model.send(.generate) }
        await generator.waitUntilStarted()
        XCTAssertEqual(model.state.suggestion, suggestion)
        generator.finish(.failure(MemoryAidGenerationError.refused))
        await request.value
        XCTAssertEqual(model.state.suggestion, suggestion)
        XCTAssertTrue(model.state.isSaved)
        XCTAssertNotNil(model.state.generationError)
    }

    @MainActor
    func testSaveFailureRetainsUnsavedResultAndRetryPersistsIt() async {
        let repository = MemoryAidTestRepository()
        let generator = MemoryAidTestGenerator()
        let model = makeModel(repository, generator)
        await model.send(.load)
        let request = Task { await model.send(.generate) }
        await generator.waitUntilStarted()
        generator.finish(.success(suggestion))
        await request.value
        repository.failSave = true
        await model.send(.save)
        XCTAssertEqual(model.state.suggestion, suggestion)
        XCTAssertFalse(model.state.isSaved)
        XCTAssertNotNil(model.state.saveError)
        repository.failSave = false
        await model.send(.save)
        XCTAssertTrue(model.state.isSaved)
        XCTAssertEqual(repository.saved, suggestion)
        XCTAssertNil(model.state.saveError)
    }

    @MainActor
    func testLoadFailureCanRetryWithoutDiscardingVisibleSuggestion() async {
        let repository = MemoryAidTestRepository()
        repository.saved = suggestion
        let generator = MemoryAidTestGenerator()
        let model = makeModel(repository, generator)
        await model.send(.load)
        repository.failLoad = true
        await model.send(.load)
        XCTAssertEqual(model.state.suggestion, suggestion)
        XCTAssertNotNil(model.state.loadError)
        repository.failLoad = false
        await model.send(.load)
        XCTAssertNil(model.state.loadError)
        XCTAssertTrue(model.state.isSaved)
    }

    @MainActor
    func testAvailabilityRefreshEnablesGenerationAfterSettingsChange() async {
        let repository = MemoryAidTestRepository()
        let generator = MemoryAidTestGenerator()
        generator.availability = .notEnabled
        let model = makeModel(repository, generator)
        XCTAssertFalse(model.state.canGenerate)
        generator.availability = .available
        await model.send(.refreshAvailability)
        XCTAssertTrue(model.state.canGenerate)
    }

    @MainActor
    func testRegeneratingSameSavedSuggestionRemainsSaved() async {
        let repository = MemoryAidTestRepository()
        repository.saved = suggestion
        let generator = MemoryAidTestGenerator()
        let model = makeModel(repository, generator)
        await model.send(.load)
        let request = Task { await model.send(.generate) }
        await generator.waitUntilStarted()
        generator.finish(.success(suggestion))
        await request.value
        XCTAssertTrue(model.state.isSaved)
        XCTAssertEqual(repository.saves, 0)
    }

    private var suggestion: MemoryAidSuggestion {
        .init(explanation: "A general rule.", mnemonic: "Picture one rule guiding your choices.")
    }

    @MainActor
    private func makeModel(_ repository: MemoryAidTestRepository, _ generator: MemoryAidTestGenerator) -> MemoryAidViewModel {
        MemoryAidViewModel(word: .init(id: "word", headword: "原則", reading: "げんそく", meanings: ["principle", "general rule"], level: "N1"), repository: repository, generator: generator)
    }
}

private final class MemoryAidTestRepository: MemoryAidRepository {
    var saved: MemoryAidSuggestion?
    var saves = 0
    var failLoad = false
    var failSave = false

    func load(for word: MemoryAidWord) throws -> MemoryAidSuggestion? {
        if failLoad { throw NSError(domain: "load", code: 1) }
        return saved
    }

    func save(_ suggestion: MemoryAidSuggestion, for word: MemoryAidWord) throws {
        saves += 1
        if failSave { throw NSError(domain: "save", code: 1) }
        saved = suggestion
    }
}

@MainActor
private final class MemoryAidTestGenerator: MemoryAidGenerating {
    var availability: MemoryAidAvailability = .available
    private(set) var requests = 0
    private var pending: [CheckedContinuation<MemoryAidSuggestion, Error>] = []
    private var started: CheckedContinuation<Void, Never>?

    func generate(for word: MemoryAidWord) async throws -> MemoryAidSuggestion {
        requests += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted(requestCount: Int? = nil) async {
        if let requestCount {
            if requests >= requestCount { return }
        } else if !pending.isEmpty { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish(_ result: Result<MemoryAidSuggestion, Error>) {
        pending.removeFirst().resume(with: result)
    }
}
