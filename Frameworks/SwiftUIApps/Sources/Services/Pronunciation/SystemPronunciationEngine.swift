import AVFoundation
import Foundation

@MainActor
final class SystemPronunciationEngine: NSObject, PronunciationEngine, AVSpeechSynthesizerDelegate {
    private let activateAudio: (() throws -> Void)?
    private let deactivateAudio: (() -> Void)?
    private var lease: UUID?
    private let coordinator: AudioSessionCoordinator
    private let synthesizer = AVSpeechSynthesizer()
    private var active: (utterance: AVSpeechUtterance, id: UUID, completion: (UUID) -> Void)?

    var hasJapaneseVoice: Bool { japaneseVoice != nil }

    private var japaneseVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter {
                $0.language.split(separator: "-").first == "ja"
                    && !$0.voiceTraits.contains(.isPersonalVoice)
                    && !$0.voiceTraits.contains(.isNoveltyVoice)
            }
            .sorted { $0.identifier < $1.identifier }
            .first
    }

    init(coordinator: AudioSessionCoordinator? = nil, activateAudio: (() throws -> Void)? = nil, deactivateAudio: (() -> Void)? = nil) {
        self.coordinator = coordinator ?? .shared
        self.activateAudio = activateAudio
        self.deactivateAudio = deactivateAudio
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void) throws {
        stop()
        guard let voice = japaneseVoice else { throw SpeechError.voiceUnavailable }
        // Listen is explicit playback; the default ambient session obeys the Silent switch.
        lease = try coordinator.acquire(.playback, activate: activateAudio, deactivate: deactivateAudio) { [weak self] in
            guard let self else { return }
            let previous = self.active
            self.stop()
            if let previous { previous.completion(previous.id) }
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        active = (utterance, id, completion)
        synthesizer.speak(utterance)
    }

    func stop() {
        active = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        releaseAudioSession()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finished(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finished(utterance) }
    }

    private enum SpeechError: Error { case voiceUnavailable }

    private func releaseAudioSession() {
        guard let lease else { return }
        self.lease = nil
        coordinator.release(lease)
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard let current = active, current.utterance === utterance else { return }
        active = nil
        releaseAudioSession()
        current.completion(current.id)
    }
}
