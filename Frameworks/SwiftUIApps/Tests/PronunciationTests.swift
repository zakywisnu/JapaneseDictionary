import AVFoundation
import Foundation
import XCTest
@testable import SwiftUIApps

@MainActor
final class PronunciationTests: XCTestCase {
    func testSystemPlaybackUsesAudioSessionThatIsNotSilencedBySilentMode() throws {
        let engine = SystemPronunciationEngine()
        guard engine.hasJapaneseVoice else { throw XCTSkip("No Japanese voice installed") }
        defer { engine.stop() }
        try engine.speak("こんにちは", id: UUID()) { _ in }
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        XCTAssertEqual(AVAudioSession.sharedInstance().mode, .spokenAudio)
    }

    func testAudioStartFailureShowsRetryWithoutLeavingPlaybackActive() {
        let engine = FakePronunciationEngine()
        engine.startError = NSError(domain: "AudioStart", code: 1)
        let timer = ManualPronunciationTimeout()
        let service = PronunciationService(engine: engine, scheduleTimeout: timer.schedule)
        service.listen(reading: "ねこ")
        guard case .failed = service.state else { return XCTFail("Expected visible audio error") }
        XCTAssertNil(service.activeID)
        XCTAssertTrue(timer.delays.isEmpty)
        engine.startError = nil
        service.listen(reading: "ねこ")
        XCTAssertEqual(service.state, .playing)
    }

    func testSystemEngineReleasesSessionOnStopAndPropagatesActivationFailure() throws {
        var events: [String] = []
        let engine = SystemPronunciationEngine(activateAudio: { events.append("activate") }, deactivateAudio: { events.append("deactivate") })
        guard engine.hasJapaneseVoice else { throw XCTSkip("No Japanese voice installed") }
        try engine.speak("こんにちは", id: UUID()) { _ in }
        engine.stop()
        engine.stop()
        XCTAssertEqual(events, ["activate", "deactivate"])
        let failure = SystemPronunciationEngine(activateAudio: { throw NSError(domain: "AudioStart", code: 1) }, deactivateAudio: { XCTFail("Never activated") })
        XCTAssertThrowsError(try failure.speak("ねこ", id: UUID()) { _ in })
        failure.stop()
    }

    func testSystemEngineCompletesJapanesePlayback() async throws {
        let engine = SystemPronunciationEngine()
        guard engine.hasJapaneseVoice else { throw XCTSkip("No Japanese voice installed") }
        let completed = expectation(description: "Actual speech playback completed")
        try engine.speak("こんにちは", id: UUID()) { _ in completed.fulfill() }
        await fulfillment(of: [completed], timeout: 8)
        engine.stop()
    }

    func testJapaneseVoiceProducesAudioSamples() async throws {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ja") }.sorted { $0.identifier < $1.identifier }
        let voice = try XCTUnwrap(voices.first)
        let synth = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "こんにちは")
        utterance.voice = voice
        let generated = expectation(description: "Japanese audio samples: " + voices.map { $0.identifier }.joined(separator: ", "))
        let lock = NSLock()
        var done = false
        synth.write(utterance) { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else { return }
            lock.lock()
            if !done { done = true; generated.fulfill() }
            lock.unlock()
        }
        await fulfillment(of: [generated], timeout: 8)
        synth.stopSpeaking(at: .immediate)
    }

    func testUnavailableVoiceRefusesPlaybackAndCanBeCheckedAgain() {
        let engine = FakePronunciationEngine()
        engine.hasJapaneseVoice = false
        let service = PronunciationService(engine: engine)
        service.listen(reading: "ねこ")
        XCTAssertEqual(service.state, .unavailable)
        XCTAssertNil(service.activeID)
        XCTAssertTrue(engine.requests.isEmpty)
        engine.hasJapaneseVoice = true
        service.refreshAvailability()
        XCTAssertEqual(service.state, .idle)
    }

    func testReplacementIgnoresOldCompletionAndOldTimeout() {
        let engine = FakePronunciationEngine()
        let timer = ManualPronunciationTimeout()
        let service = PronunciationService(engine: engine, scheduleTimeout: timer.schedule)
        service.listen(reading: "ねこ")
        let oldID = service.activeID!
        service.listen(reading: "いぬ")
        let newID = service.activeID!
        XCTAssertNotEqual(oldID, newID)
        XCTAssertEqual(engine.stopCount, 1)
        engine.complete(oldID)
        timer.fire(0)
        XCTAssertEqual(service.activeID, newID)
        XCTAssertEqual(service.state, .playing)
        engine.complete(newID)
        XCTAssertEqual(service.state, .idle)
        XCTAssertNil(service.activeID)
        XCTAssertTrue(timer.cancelled.contains(1))
    }

    func testInvalidReadingRejectsWithoutGuessingAndStopsPreviousAudio() {
        let engine = FakePronunciationEngine()
        let service = PronunciationService(engine: engine)
        service.listen(reading: "ねこ")
        service.listen(reading: "猫")
        guard case .failed = service.state else { return XCTFail("Expected reading failure") }
        XCTAssertNil(service.activeID)
        XCTAssertEqual(engine.requests.count, 1)
        XCTAssertEqual(engine.stopCount, 1)
        for reading in ["", "   ", String(repeating: "あ", count: 201), "いち、に", "abc", "ー", "."] {
            XCTAssertNil(PronunciationService.normalizedReading(reading), reading)
        }
    }

    func testOnlyInflectionMarkersAreRemovedFromSuppliedKana() {
        let engine = FakePronunciationEngine()
        let service = PronunciationService(engine: engine)
        let display = "  た.べる  "
        service.listen(reading: display)
        XCTAssertEqual(display, "  た.べる  ")
        XCTAssertEqual(engine.requests.first?.text, "たべる")
        XCTAssertEqual(PronunciationService.normalizedReading("-ショク"), "ショク")
        XCTAssertEqual(PronunciationService.normalizedReading("コーヒー"), "コーヒー")
        XCTAssertNil(PronunciationService.normalizedReading("ねこ/いぬ"))
    }

    func testStopAndBackgroundClearActiveSpeechAndForegroundRefreshesVoice() {
        let engine = FakePronunciationEngine()
        let timer = ManualPronunciationTimeout()
        let service = PronunciationService(engine: engine, scheduleTimeout: timer.schedule)
        service.listen(reading: "ねこ")
        service.stop()
        XCTAssertEqual(service.state, .idle)
        XCTAssertNil(service.activeID)
        XCTAssertTrue(timer.cancelled.contains(0))
        service.listen(reading: "いぬ")
        service.didEnterBackground()
        XCTAssertEqual(service.state, .idle)
        XCTAssertNil(service.activeID)
        engine.hasJapaneseVoice = false
        service.willEnterForeground()
        XCTAssertEqual(service.state, .unavailable)
    }

    func testTimeoutStopsStalledPlaybackAndAllowsRetry() {
        let engine = FakePronunciationEngine()
        let timer = ManualPronunciationTimeout()
        let service = PronunciationService(engine: engine, scheduleTimeout: timer.schedule)
        service.listen(reading: "ねこ")
        XCTAssertEqual(timer.delays.first, 15)
        timer.fire(0)
        XCTAssertNil(service.activeID)
        guard case let .failed(message) = service.state else { return XCTFail("Expected timeout failure") }
        XCTAssertTrue(message.contains("Try again"))
        XCTAssertEqual(engine.stopCount, 1)
        service.listen(reading: String(repeating: "あ", count: 200))
        XCTAssertEqual(service.state, .playing)
        XCTAssertEqual(timer.delays.last, 60)
    }

    func testSynchronousCompletionDoesNotLeavePlayingOrScheduleTimeout() {
        let engine = FakePronunciationEngine()
        engine.completesImmediately = true
        let timer = ManualPronunciationTimeout()
        let service = PronunciationService(engine: engine, scheduleTimeout: timer.schedule)
        service.listen(reading: "ねこ")
        XCTAssertEqual(service.state, .idle)
        XCTAssertNil(service.activeID)
        XCTAssertTrue(timer.delays.isEmpty)
    }
}

@MainActor
private final class FakePronunciationEngine: PronunciationEngine {
    var startError: Error?
    var hasJapaneseVoice = true
    var stopCount = 0
    var completesImmediately = false
    var requests: [(text: String, id: UUID)] = []
    var callbacks: [UUID: (UUID) -> Void] = [:]
    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void) throws {
        if let startError { throw startError }
        requests.append((text, id))
        callbacks[id] = completion
        if completesImmediately { completion(id) }
    }
    func stop() { stopCount += 1 }
    func complete(_ id: UUID) { callbacks[id]?(id) }
}

@MainActor
private final class ManualPronunciationTimeout {
    var delays: [TimeInterval] = []
    var actions: [@MainActor () -> Void] = []
    var cancelled: Set<Int> = []
    func schedule(_ delay: TimeInterval, action: @escaping @MainActor () -> Void) -> () -> Void {
        let index = actions.count
        delays.append(delay)
        actions.append(action)
        return { self.cancelled.insert(index) }
    }
    // Fire cancelled work too: queued callbacks must be safe after replacement.
    func fire(_ index: Int) { actions[index]() }
}
