import AVFoundation
import UIKit
import DomainKit
import Foundation
import XCTest
@testable import SwiftUIApps

@MainActor
final class SpeakingLifecycleTests: XCTestCase {
    func testUnavailableLocalRecognitionRequestsNeitherPermissionNorRecognition() async {
        let recognition = FakeLocalRecognition()
        recognition.isAvailable = false
        var permissions = 0
        let service = SpeakingRecorder(recognition: recognition, microphonePermission: { permissions += 1; return true }, speechPermission: { permissions += 1; return true })
        let allowed = await service.requestPermissions()
        XCTAssertFalse(allowed)
        XCTAssertEqual(service.availability, .localRecognitionUnavailable)
        XCTAssertEqual(permissions, 0)
        XCTAssertEqual(recognition.requests, 0)
        XCTAssertThrowsError(try service.startRecording())
    }

    func testDeniedMicrophoneDoesNotRequestSpeech() async {
        var speechRequests = 0
        let service = SpeakingRecorder(recognition: FakeLocalRecognition(), microphonePermission: { false }, speechPermission: { speechRequests += 1; return true })
        let allowed = await service.requestPermissions()
        XCTAssertFalse(allowed)
        XCTAssertEqual(service.availability, .microphoneDenied)
        XCTAssertEqual(speechRequests, 0)
    }

    func testDeniedSpeechStopsCapturePermissionFlow() async {
        let service = SpeakingRecorder(recognition: FakeLocalRecognition(), microphonePermission: { true }, speechPermission: { false })
        let allowed = await service.requestPermissions()
        XCTAssertFalse(allowed)
        XCTAssertEqual(service.availability, .speechDenied)
        XCTAssertThrowsError(try service.startRecording())
    }

    func testAudioLeasePreventsOldOwnerFromReleasingNewSession() throws {
        var activations = 0
        var releases = 0
        var stopped = 0
        let audio = AudioSessionCoordinator(activate: { _ in activations += 1 }, deactivate: { releases += 1 })
        let playback = try audio.acquire(.playback) { stopped += 1 }
        let capture = try audio.acquire(.recording) {}
        XCTAssertEqual(stopped, 1)
        XCTAssertEqual(releases, 1)
        audio.release(playback)
        XCTAssertEqual(releases, 1)
        audio.release(capture)
        XCTAssertEqual(releases, 2)
        let next = try audio.acquire(.playback) {}
        XCTAssertEqual(activations, 3)
        audio.release(next)
    }

    func testCaptureActivationErrorCleansTemporaryFileAndAllowsListenOwnership() async throws {
        let audio = AudioSessionCoordinator(activate: { purpose in
            if case .recording = purpose { throw SpeakingError.recordingFailed }
        }, deactivate: {})
        let service = SpeakingRecorder(recognition: FakeLocalRecognition(), audio: audio, microphonePermission: { true }, speechPermission: { true })
        let allowed = await service.requestPermissions()
        XCTAssertTrue(allowed)
        XCTAssertThrowsError(try service.startRecording())
        do { _ = try await service.stopRecording(); XCTFail("Failed capture retained a recording") } catch {}
        let lease = try audio.acquire(.playback) {}
        audio.release(lease)
    }

    func testBackgroundInvalidatesPendingPermission() async {
        var resume: CheckedContinuation<Bool, Never>?
        let service = SpeakingRecorder(recognition: FakeLocalRecognition(), microphonePermission: {
            await withCheckedContinuation { resume = $0 }
        }, speechPermission: { XCTFail("Backgrounded flow requested speech"); return true })
        let task = Task { await service.requestPermissions() }
        while resume == nil { await Task.yield() }
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        resume?.resume(returning: true)
        let allowed = await task.value
        XCTAssertFalse(allowed)
    }

    func testInterruptionInvalidatesPendingPermission() async {
        var resume: CheckedContinuation<Bool, Never>?
        let service = SpeakingRecorder(recognition: FakeLocalRecognition(), microphonePermission: {
            await withCheckedContinuation { resume = $0 }
        }, speechPermission: { XCTFail("Interrupted flow requested speech"); return true })
        let task = Task { await service.requestPermissions() }
        while resume == nil { await Task.yield() }
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        resume?.resume(returning: true)
        let allowed = await task.value
        XCTAssertFalse(allowed)
    }

    func testSentenceReadingPreservesVoicingLongVowelsAndSmallKana() {
        XCTAssertEqual(SpeechTextValidator.normalizedReading("  がっこう、コーヒー。  "), "がっこう、コーヒー。")
        XCTAssertEqual(SpeechTextValidator.normalizedReading("きょう は？"), "きょう は？")
        XCTAssertEqual(SpeechTextValidator.normalizedReading("た.べる"), "たべる")
        for invalid in ["学校", "abc", "。", String(repeating: "あ", count: 201)] {
            XCTAssertNil(SpeechTextValidator.normalizedReading(invalid))
        }
    }

    func testCancellationInvalidatesPendingPermission() async {
        var resume: CheckedContinuation<Bool, Never>?
        let service = SpeakingRecorder(recognition: FakeLocalRecognition(), microphonePermission: {
            await withCheckedContinuation { resume = $0 }
        }, speechPermission: { XCTFail("Cancelled flow requested speech"); return true })
        let task = Task { await service.requestPermissions() }
        while resume == nil { await Task.yield() }
        service.cancel()
        resume?.resume(returning: true)
        let allowed = await task.value
        XCTAssertFalse(allowed)
    }
}

@MainActor
private final class FakeLocalRecognition: LocalSpeechRecognizing {
    var isAvailable = true
    var requests = 0
    func recognize(_ url: URL) async throws -> SpeechRecognitionEvidence {
        requests += 1
        return .init(transcript: "ねこ", isFinal: true)
    }
    func cancel() {}
}
