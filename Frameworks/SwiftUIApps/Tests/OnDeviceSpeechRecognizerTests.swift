import XCTest
import Speech
import AVFoundation
import DomainKit
@testable import SwiftUIApps

@MainActor final class OnDeviceSpeechRecognizerTests: XCTestCase {
    func testUnavailableOnDeviceCapabilityCreatesNoTask() async {
        let backend = Backend()
        backend.supportsOnDeviceRecognition = false
        let recognizer = OnDeviceSpeechRecognizer(backend: backend)
        do { _ = try await recognizer.recognize(URL(fileURLWithPath: "/tmp/unused.m4a")); XCTFail("Expected offline capability rejection") }
        catch { XCTAssertEqual(backend.requests.count, 0) }
    }
    func testRequestRequiresLocalRecognitionWithoutTargetBias() async throws {
        let backend = Backend()
        let recognizer = OnDeviceSpeechRecognizer(backend: backend)
        let result = try await recognizer.recognize(URL(fileURLWithPath: "/tmp/unused.m4a"))
        XCTAssertEqual(result.transcript, "こんにちは")
        let request = try XCTUnwrap(backend.requests.first)
        XCTAssertTrue(request.requiresOnDeviceRecognition)
        XCTAssertEqual(request.contextualStrings, [])
        XCTAssertFalse(request.shouldReportPartialResults)
    }
    func testRouteChangesIgnoreCategoryChanges() {
        XCTAssertFalse(AudioSessionCoordinator.isExternalRouteChange(.init(name: AVAudioSession.routeChangeNotification, userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.categoryChange.rawValue])))
        XCTAssertTrue(AudioSessionCoordinator.isExternalRouteChange(.init(name: AVAudioSession.routeChangeNotification, userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])))
    }
    private final class Backend: SpeechRecognizerBackend {
        var supportsOnDeviceRecognition = true
        var isAvailable = true
        var requests: [SFSpeechURLRecognitionRequest] = []
        func start(request: SFSpeechURLRecognitionRequest, completion: @escaping (SpeechRecognitionEvidence?, Error?) -> Void) -> any SpeechRecognitionTaskCancelling {
            requests.append(request)
            completion(.init(transcript: "こんにちは", isFinal: true), nil)
            return Cancellation()
        }
    }
    private struct Cancellation: SpeechRecognitionTaskCancelling { func cancel() {} }
}
