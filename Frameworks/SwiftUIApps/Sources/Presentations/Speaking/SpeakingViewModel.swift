import AVFoundation
import DomainKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SpeakingViewModel {
    enum Phase: Equatable { case ready, requestingPermission, recording, recorded, comparing }
    struct State {
        var phase: Phase = .ready
        var availability: SpeakingAvailability = .supported
        var recording: SpeakingRecording?
        var evidence: SpeechRecognitionEvidence?
        var comparison: SpeakingComparisonResult?
        var error: String?
        var isExplaining = false
        var explanation: SpeakingFeedback?
        var explanationError: String?
    }
    enum Action { case record, stop, replay, compare, cancelComparison, retry, explain, cancelExplanation, sceneChanged(ScenePhase), exit }
    let target: SpeakingTarget
    let pronunciation: PronunciationService
    private(set) var state = State()
    @ObservationIgnored private let service: any SpeakingServicing
    @ObservationIgnored private let explainer: any SpeakingFeedbackGenerating
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var explanationTask: Task<Void, Never>?
    @ObservationIgnored private var limitTask: Task<Void, Never>?
    @ObservationIgnored private var operationID = UUID()
    @ObservationIgnored private var explanationID = UUID()
    @ObservationIgnored private let recordingLimit: UInt64
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var routeObserver: NSObjectProtocol?

    init(target: SpeakingTarget, service: any SpeakingServicing, pronunciation: PronunciationService, explainer: any SpeakingFeedbackGenerating, recordingLimit: UInt64 = 15_000_000_000) {
        self.target = target; self.service = service; self.pronunciation = pronunciation; self.explainer = explainer; self.recordingLimit = recordingLimit
        state.availability = service.availability
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.send(.exit)
                self.state.error = "Audio was interrupted. Try recording again."
            }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                guard AudioSessionCoordinator.isExternalRouteChange(notification), let self,
                      self.state.phase != .ready else { return }
                self.send(.exit)
                self.state.error = "Your audio input or output changed. Try recording again."
            }
        }
    }

    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
        task?.cancel(); explanationTask?.cancel(); limitTask?.cancel()
    }

    var explanationAvailability: MemoryAidAvailability { explainer.availability }
    var canRecord: Bool { SpeechTextValidator.normalizedReading(target.suppliedReading) != nil && state.availability != .localRecognitionUnavailable }

    func send(_ action: Action) {
        switch action {
        case .record:
            guard state.phase == .ready, canRecord else { return }
            pronunciation.stop()
            state.error = nil
            state.phase = .requestingPermission
            let id = operationID
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                let allowed = await service.requestPermissions()
                guard operationID == id, !Task.isCancelled else { return }
                state.availability = service.availability
                guard allowed else { state.phase = .ready; return }
                do {
                    try service.startRecording()
                    state.phase = .recording
                    limitTask = Task { @MainActor [weak self] in
                        guard let self else { return }
                        do { try await Task.sleep(nanoseconds: recordingLimit) } catch { return }
                        guard operationID == id else { return }
                        send(.stop)
                    }
                } catch { state.phase = .ready; state.error = "Recording couldn't start. Check microphone access and try again." }
            }
        case .stop:
            guard state.phase == .recording else { return }
            limitTask?.cancel(); limitTask = nil
            state.phase = .recorded
            let id = operationID
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let recording = try await service.stopRecording()
                    guard operationID == id, !Task.isCancelled else { return }
                    state.recording = recording
                } catch {
                    guard operationID == id, !Task.isCancelled else { return }
                    state.phase = .ready; state.error = "No recording could be kept. Try recording again."
                }
            }
        case .replay:
            guard let recording = state.recording, state.phase == .recorded else { return }
            pronunciation.stop()
            do { try service.replay(recording) } catch { state.error = "Your recording couldn't play. Try recording again." }
        case .compare:
            guard let recording = state.recording, state.phase == .recorded else { return }
            pronunciation.stop()
            state.phase = .comparing; state.error = nil
            let id = operationID
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let evidence = try await service.recognize(recording)
                    guard operationID == id, !Task.isCancelled else { return }
                    state.evidence = evidence
                    state.comparison = SpeakingComparison.compare(target: target, evidence: evidence)
                } catch {
                    guard operationID == id, !Task.isCancelled else { return }
                    state.error = "No final phrase could be recognized on this iPhone. Replay your recording or try again in a quieter place."
                }
                state.phase = .recorded
            }
        case .cancelComparison:
            guard state.phase == .comparing else { return }
            operationID = UUID()
            task?.cancel(); task = nil
            service.cancelRecognition()
            state.phase = .recorded
            state.error = nil
        case .retry:
            clearWork()
            state = State(); state.availability = service.availability
        case .explain:
            guard let evidence = state.evidence, let comparison = state.comparison, !state.isExplaining, explainer.availability == .available else { return }
            let id = UUID(); explanationID = id
            state.isExplaining = true; state.explanationError = nil
            explanationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let feedback = try await explainer.generate(target: target, evidence: evidence, comparison: comparison)
                    guard explanationID == id, !Task.isCancelled else { return }
                    state.explanation = try feedback.validated()
                } catch {
                    guard explanationID == id, !Task.isCancelled else { return }
                    state.explanationError = "The optional explanation couldn't be generated. Your transcript comparison is still available. Try again."
                }
                state.isExplaining = false
            }
        case .cancelExplanation:
            explanationID = UUID(); explanationTask?.cancel(); explanationTask = nil; state.isExplaining = false
        case .sceneChanged(let phase):
            // System consent prompts temporarily inactivate the scene during permission requests.
            if phase == .background { send(.exit) }
        case .exit:
            clearWork(); state = State(); state.availability = service.availability
        }
    }

    private func clearWork() {
        operationID = UUID(); explanationID = UUID()
        task?.cancel(); explanationTask?.cancel(); limitTask?.cancel()
        task = nil; explanationTask = nil; limitTask = nil
        service.cancel(); pronunciation.stop()
    }
}
