import AVFoundation
import Foundation
import Observation
import UIKit

@MainActor
protocol PronunciationEngine: AnyObject {
    var hasJapaneseVoice: Bool { get }
    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void) throws
    func stop()
}

@MainActor
@Observable
final class PronunciationService {
    enum State: Equatable {
        case idle
        case playing
        case unavailable
        case failed(String)
    }

    typealias TimeoutScheduler = (TimeInterval, @escaping @MainActor () -> Void) -> () -> Void

    private(set) var state: State = .idle
    private(set) var activeID: UUID?
    @ObservationIgnored private let engine: any PronunciationEngine
    @ObservationIgnored private let scheduleTimeout: TimeoutScheduler
    @ObservationIgnored private var cancelTimeout: (() -> Void)?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(engine: any PronunciationEngine, scheduleTimeout: TimeoutScheduler? = nil) {
        self.engine = engine
        self.scheduleTimeout = scheduleTimeout ?? Self.schedulePlaybackTimeout
        refreshAvailability()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.didEnterBackground() }
        })
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.willEnterForeground() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawValue) == .began else { return }
            MainActor.assumeIsolated { self?.playbackInterrupted() }
        })
    }

    convenience init() {
        self.init(engine: SystemPronunciationEngine())
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        cancelTimeout?()
    }

    func refreshAvailability() {
        guard engine.hasJapaneseVoice else {
            clearPlayback()
            state = .unavailable
            return
        }
        if state == .unavailable { state = .idle }
    }

    func listen(reading: String) {
        clearPlayback()
        guard engine.hasJapaneseVoice else {
            state = .unavailable
            return
        }
        guard let text = Self.normalizedReading(reading) else {
            state = .failed("This reading cannot be spoken. Choose a supplied kana reading and try again.")
            return
        }
        let id = UUID()
        activeID = id
        state = .playing
        do {
            try engine.speak(text, id: id) { [weak self] finishedID in
                guard let self, self.activeID == finishedID else { return }
                self.cancelTimeout?()
                self.cancelTimeout = nil
                self.activeID = nil
                self.state = .idle
            }
        } catch {
            clearPlayback()
            state = .failed("Pronunciation couldn't start. Check your audio output and try again.")
            return
        }
        // Engines may complete synchronously; never install a timeout for finished audio.
        guard activeID == id else { return }
        let timeout = min(60, max(15, Double(text.count) * 0.4))
        cancelTimeout = scheduleTimeout(timeout) { [weak self] in
            guard let self, self.activeID == id else { return }
            self.clearPlayback()
            self.state = .failed("Pronunciation did not finish. Try again.")
        }
    }

    func stop() {
        clearPlayback()
        state = engine.hasJapaneseVoice ? .idle : .unavailable
    }

    func didEnterBackground() { stop() }
    func willEnterForeground() { refreshAvailability() }

    static func normalizedReading(_ reading: String) -> String? {
        let trimmed = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { return nil }
        let text = trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "-", with: "")
            .precomposedStringWithCanonicalMapping
        var hasKana = false
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3041...0x3096, 0x30A1...0x30FA:
                hasKana = true
            case 0x30FC, 0x309D...0x309E, 0x30FD...0x30FE:
                break
            default:
                return nil
            }
        }
        return hasKana ? text : nil
    }

    private func clearPlayback() {
        cancelTimeout?()
        cancelTimeout = nil
        let wasPlaying = activeID != nil
        // Invalidate identity before stop, whose cancellation delegate may run immediately.
        activeID = nil
        if wasPlaying { engine.stop() }
    }

    private func playbackInterrupted() {
        guard activeID != nil else { return }
        clearPlayback()
        state = .failed("Pronunciation was interrupted. Try again.")
    }

    private static func schedulePlaybackTimeout(_ delay: TimeInterval, action: @escaping @MainActor () -> Void) -> () -> Void {
        let task = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
            guard !Task.isCancelled else { return }
            action()
        }
        return { task.cancel() }
    }
}
