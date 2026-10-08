import AVFoundation
import Foundation

@MainActor
final class SystemPronunciationEngine: NSObject, PronunciationEngine, AVSpeechSynthesizerDelegate {
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

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, id: UUID, completion: @escaping (UUID) -> Void) {
        stop()
        guard let voice = japaneseVoice else { return }
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
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finished(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finished(utterance) }
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard let current = active, current.utterance === utterance else { return }
        active = nil
        current.completion(current.id)
    }
}
