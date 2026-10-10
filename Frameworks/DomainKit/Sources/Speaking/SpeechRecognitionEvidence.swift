import Foundation

public struct SpeechRecognitionEvidence: Equatable, Sendable {
    public let transcript: String
    public let isFinal: Bool
    public init(transcript: String, isFinal: Bool) {
        self.transcript = transcript
        self.isFinal = isFinal
    }
}
