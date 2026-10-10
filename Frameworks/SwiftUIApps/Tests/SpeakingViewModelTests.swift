import AVFoundation
import DomainKit
import Foundation
import XCTest
@testable import SwiftUIApps

@MainActor
final class SpeakingViewModelTests: XCTestCase {
    func testRecordingStopReplayAndFinalCompare() async {
        let service = FakeSpeakingService()
        let model = make(service)
        model.send(.record)
        await settle()
        XCTAssertEqual(model.state.phase, .recording)
        model.send(.stop)
        await settle()
        XCTAssertEqual(model.state.phase, .recorded)
        XCTAssertNotNil(model.state.recording)
        model.send(.replay)
        XCTAssertEqual(service.replayCount, 1)
        model.send(.compare)
        await settle()
        XCTAssertEqual(model.state.comparison?.outcome, .match)
        XCTAssertEqual(model.state.phase, .recorded)
        model.send(.exit)
    }

    func testRecognitionFailureRetainsReplayAndRetryDeletesSession() async {
        let service = FakeSpeakingService(); service.recognitionFails = true
        let model = make(service)
        await record(model)
        model.send(.compare)
        await settle()
        XCTAssertNotNil(model.state.error)
        XCTAssertNotNil(model.state.recording)
        model.send(.replay)
        XCTAssertEqual(service.replayCount, 1)
        model.send(.retry)
        XCTAssertNil(model.state.recording)
        XCTAssertEqual(model.state.phase, .ready)
        XCTAssertEqual(service.cancelCount, 1)
    }

    func testRecordingLimitStopsAutomatically() async throws {
        let service = FakeSpeakingService()
        let model = make(service, limit: 1_000_000)
        model.send(.record)
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(model.state.phase, .recorded)
        XCTAssertEqual(service.stopCount, 1)
        model.send(.exit)
    }

    func testExitIgnoresStaleRecognition() async {
        let service = FakeSpeakingService(); service.delaysRecognition = true
        let model = make(service)
        await record(model)
        model.send(.compare)
        while service.pendingRecognition == nil { await Task.yield() }
        model.send(.exit)
        service.pendingRecognition?.resume(returning: .init(transcript: "ねこ", isFinal: true))
        service.pendingRecognition = nil
        await settle()
        XCTAssertNil(model.state.comparison)
        XCTAssertNil(model.state.recording)
        XCTAssertEqual(model.state.phase, .ready)
    }

    func testPermissionPromptInactivityPreservesRecordAction() async {
        let service = FakeSpeakingService(); service.delaysPermission = true
        let model = make(service)
        model.send(.record)
        while service.pendingPermission == nil { await Task.yield() }
        model.send(.sceneChanged(.inactive))
        XCTAssertEqual(model.state.phase, .requestingPermission)
        XCTAssertEqual(service.cancelCount, 0)
        model.send(.sceneChanged(.active))
        service.pendingPermission?.resume(returning: true)
        service.pendingPermission = nil
        await settle()
        XCTAssertEqual(model.state.phase, .recording)
        XCTAssertEqual(service.startCount, 1)
        model.send(.exit)
    }

    func testBackgroundCancelsPendingRecordAction() async {
        let service = FakeSpeakingService(); service.delaysPermission = true
        let model = make(service)
        model.send(.record)
        while service.pendingPermission == nil { await Task.yield() }
        model.send(.sceneChanged(.background))
        service.pendingPermission?.resume(returning: true)
        service.pendingPermission = nil
        await settle()
        XCTAssertEqual(model.state.phase, .ready)
        XCTAssertEqual(service.startCount, 0)
        XCTAssertEqual(service.cancelCount, 1)
    }

    func testCancelComparisonRetainsReplayAndIgnoresLateResult() async {
        let service = FakeSpeakingService(); service.delaysRecognition = true
        let model = make(service)
        await record(model)
        let recording = model.state.recording
        model.send(.compare)
        while service.pendingRecognition == nil { await Task.yield() }
        model.send(.cancelComparison)
        XCTAssertEqual(model.state.phase, .recorded)
        XCTAssertEqual(model.state.recording, recording)
        XCTAssertEqual(service.cancelRecognitionCount, 1)
        XCTAssertEqual(service.cancelCount, 0)
        model.send(.replay)
        XCTAssertEqual(service.replayCount, 1)
        service.pendingRecognition?.resume(returning: .init(transcript: "ねこ", isFinal: true))
        service.pendingRecognition = nil
        await settle()
        XCTAssertNil(model.state.comparison)
        XCTAssertEqual(model.state.recording, recording)
        model.send(.exit)
    }

    func testInterruptedRecordingResetsStateWithActionableError() async {
        let service = FakeSpeakingService()
        let model = make(service)
        model.send(.record); await settle()
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        XCTAssertEqual(model.state.phase, .ready)
        XCTAssertTrue(model.state.error?.contains("interrupted") == true)
    }

    func testPartialEvidenceIsInconclusive() async {
        let service = FakeSpeakingService(); service.evidence = .init(transcript: "ねこ", isFinal: false)
        let model = make(service)
        await record(model); model.send(.compare); await settle()
        XCTAssertEqual(model.state.comparison?.outcome, .inconclusive)
        model.send(.exit)
    }

    func testDeniedPermissionOffersRecordAgainAfterSettings() async {
        let service = FakeSpeakingService(); service.permission = false; service.availability = .microphoneDenied
        let model = make(service)
        model.send(.record); await settle()
        XCTAssertEqual(model.state.phase, .ready)
        XCTAssertTrue(model.canRecord)
        service.permission = true; service.availability = .supported
        model.send(.record); await settle()
        XCTAssertEqual(model.state.phase, .recording)
        model.send(.exit)
    }

    func testOptionalFailureKeepsBasicResultAndStaleExplanationIsIgnored() async {
        let service = FakeSpeakingService()
        let explainer = FakeSpeakingExplainer()
        explainer.fails = true
        let model = make(service, explainer: explainer)
        await record(model); model.send(.compare); await settle()
        model.send(.explain); await settle()
        XCTAssertEqual(model.state.comparison?.outcome, .match)
        XCTAssertNotNil(model.state.explanationError)
        explainer.fails = false; explainer.delays = true
        model.send(.explain)
        while explainer.pending == nil { await Task.yield() }
        model.send(.retry)
        explainer.pending?.resume(returning: .init(explanation: "Expected transcript heard.", practiceTip: "Replay your phrase."))
        explainer.pending = nil
        await settle()
        XCTAssertNil(model.state.explanation)
        XCTAssertFalse(model.state.isExplaining)
    }

    func testUnsupportedOptionalModelNeverRunsAndComparisonRemains() async {
        let service = FakeSpeakingService(); let explainer = FakeSpeakingExplainer(); explainer.availability = .modelNotReady
        let model = make(service, explainer: explainer)
        await record(model); model.send(.compare); await settle()
        model.send(.explain); await settle()
        XCTAssertEqual(explainer.requests, 0)
        XCTAssertNotNil(model.state.comparison)
        model.send(.exit)
    }

    private func record(_ model: SpeakingViewModel) async { model.send(.record); await settle(); model.send(.stop); await settle() }
    private func settle() async { for _ in 0..<10 { await Task.yield() } }
    private func make(_ service: FakeSpeakingService, explainer: FakeSpeakingExplainer? = nil, limit: UInt64 = 15_000_000_000) -> SpeakingViewModel {
        .init(target: .init(id: "t", prompt: "猫", suppliedReading: "ねこ"), service: service, pronunciation: PronunciationService(engine: SilentSpeakingPronunciation()), explainer: explainer ?? FakeSpeakingExplainer(), recordingLimit: limit)
    }
}

@MainActor
private final class FakeSpeakingService: SpeakingServicing {
    var availability: SpeakingAvailability = .supported
    var permission = true
    var replayCount = 0
    var stopCount = 0
    var cancelCount = 0
    var cancelRecognitionCount = 0
    var startCount = 0
    var delaysPermission = false
    var pendingPermission: CheckedContinuation<Bool, Never>?
    var recognitionFails = false
    var delaysRecognition = false
    var evidence = SpeechRecognitionEvidence(transcript: "猫", isFinal: true)
    var pendingRecognition: CheckedContinuation<SpeechRecognitionEvidence, Error>?
    func requestPermissions() async -> Bool {
        if delaysPermission { return await withCheckedContinuation { pendingPermission = $0 } }
        return permission
    }
    func startRecording() throws { startCount += 1 }
    func stopRecording() async throws -> SpeakingRecording {
        stopCount += 1
        return .init(id: UUID(), temporaryURL: URL(fileURLWithPath: "/tmp/fake-speaking.m4a"), duration: 1)
    }
    func recognize(_ recording: SpeakingRecording) async throws -> SpeechRecognitionEvidence {
        if recognitionFails { throw SpeakingError.noSpeech }
        if delaysRecognition { return try await withCheckedThrowingContinuation { pendingRecognition = $0 } }
        return evidence
    }
    func replay(_ recording: SpeakingRecording) throws { replayCount += 1 }
    func cancelRecognition() { cancelRecognitionCount += 1 }
    func cancel() { cancelCount += 1 }
}

@MainActor
private final class SilentSpeakingPronunciation: PronunciationEngine {
    var hasJapaneseVoice = true
    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void) throws { completion(id) }
    func stop() {}
}

@MainActor
private final class FakeSpeakingExplainer: SpeakingFeedbackGenerating {
    var availability: MemoryAidAvailability = .available
    var fails = false
    var delays = false
    var requests = 0
    var pending: CheckedContinuation<SpeakingFeedback, Error>?
    func generate(target: SpeakingTarget, evidence: SpeechRecognitionEvidence, comparison: SpeakingComparisonResult) async throws -> SpeakingFeedback {
        requests += 1
        if fails { throw SpeakingFeedbackError.failed }
        if delays { return try await withCheckedThrowingContinuation { pending = $0 } }
        return .init(explanation: "Expected transcript heard.", practiceTip: "Listen and replay the phrase.")
    }
}
