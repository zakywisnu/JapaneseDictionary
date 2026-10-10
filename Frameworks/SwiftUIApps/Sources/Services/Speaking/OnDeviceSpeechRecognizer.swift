import DomainKit
import Foundation
import Speech

@MainActor
protocol LocalSpeechRecognizing: AnyObject {
    var isAvailable: Bool { get }
    func recognize(_ url: URL) async throws -> SpeechRecognitionEvidence
    func cancel()
}

@MainActor
protocol SpeechRecognitionTaskCancelling {
    func cancel()
}

@MainActor
protocol SpeechRecognizerBackend {
    var supportsOnDeviceRecognition: Bool { get }
    var isAvailable: Bool { get }
    func start(request: SFSpeechURLRecognitionRequest, completion: @escaping (SpeechRecognitionEvidence?, Error?) -> Void) -> any SpeechRecognitionTaskCancelling
}

@MainActor
private struct JapaneseSpeechRecognizerBackend: SpeechRecognizerBackend {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    var supportsOnDeviceRecognition: Bool { recognizer?.supportsOnDeviceRecognition == true }
    var isAvailable: Bool { recognizer?.isAvailable == true }

    func start(request: SFSpeechURLRecognitionRequest, completion: @escaping (SpeechRecognitionEvidence?, Error?) -> Void) -> any SpeechRecognitionTaskCancelling {
        let task = recognizer?.recognitionTask(with: request) { result, error in
            completion(result.map { .init(transcript: $0.bestTranscription.formattedString, isFinal: $0.isFinal) }, error)
        }
        return SystemSpeechRecognitionTask(task: task)
    }
}

@MainActor
private struct SystemSpeechRecognitionTask: SpeechRecognitionTaskCancelling {
    let task: SFSpeechRecognitionTask?
    func cancel() { task?.cancel() }
}

@MainActor
final class OnDeviceSpeechRecognizer: LocalSpeechRecognizing {
    private let recognizer: any SpeechRecognizerBackend
    private var task: (any SpeechRecognitionTaskCancelling)?
    private var timeout: Task<Void, Never>?
    private var activeID: UUID?
    private var continuation: CheckedContinuation<SpeechRecognitionEvidence, Error>?
    var isAvailable: Bool { recognizer.supportsOnDeviceRecognition && recognizer.isAvailable }

    init(backend: (any SpeechRecognizerBackend)? = nil) {
        recognizer = backend ?? JapaneseSpeechRecognizerBackend()
    }

    func recognize(_ url: URL) async throws -> SpeechRecognitionEvidence {
        cancel()
        try Task.checkCancellation()
        guard recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            throw SpeakingError.localRecognitionUnavailable
        }
        let id = UUID()
        activeID = id
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.contextualStrings = []
        request.shouldReportPartialResults = false
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                timeout = Task { @MainActor [weak self] in
                    do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
                    guard let self, self.activeID == id else { return }
                    self.finish(.failure(SpeakingError.noSpeech))
                }
                task = recognizer.start(request: request) { [weak self] result, error in
                    Task { @MainActor in
                        guard let self, self.activeID == id else { return }
                        if let result, result.isFinal {
                            let text = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.finish(text.isEmpty ? .failure(SpeakingError.noSpeech) : .success(.init(transcript: text, isFinal: true)))
                        } else if let error { self.finish(.failure(error)) }
                    }
                }
            }
        } onCancel: { Task { @MainActor [weak self] in
            guard let self, self.activeID == id else { return }
            self.cancel()
        } }
    }

    func cancel() { finish(.failure(CancellationError())) }

    private func finish(_ result: Result<SpeechRecognitionEvidence, Error>) {
        activeID = nil
        timeout?.cancel()
        timeout = nil
        let pending = continuation
        continuation = nil
        task?.cancel()
        task = nil
        pending?.resume(with: result)
    }
}
