import Foundation

public struct SpeakingTarget: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let prompt: String
    public let suppliedReading: String
    public let acceptedWrittenForms: [String]
    public let isIsolatedSound: Bool
    public init(id: String, prompt: String, suppliedReading: String, acceptedWrittenForms: [String] = [], isIsolatedSound: Bool = false) {
        self.id = id; self.prompt = prompt; self.suppliedReading = suppliedReading; self.acceptedWrittenForms = acceptedWrittenForms; self.isIsolatedSound = isIsolatedSound
    }
}

public struct SpeakingComparisonResult: Equatable, Sendable {
    public enum Outcome: String, Sendable { case match, different, inconclusive }
    public let outcome: Outcome
    public let expected: String
    public let recognized: String
    public let reason: String
    public init(outcome: Outcome, expected: String, recognized: String, reason: String) {
        self.outcome = outcome; self.expected = expected; self.recognized = recognized; self.reason = reason
    }
}

public enum SpeakingComparison {
    public static func compare(target: SpeakingTarget, evidence: SpeechRecognitionEvidence) -> SpeakingComparisonResult {
        func result(_ outcome: SpeakingComparisonResult.Outcome, _ reason: String) -> SpeakingComparisonResult {
            .init(outcome: outcome, expected: target.prompt, recognized: evidence.transcript, reason: reason)
        }
        let heard = normalized(evidence.transcript)
        let reading = normalized(target.suppliedReading)
        guard evidence.isFinal, !heard.isEmpty else {
            return result(.inconclusive, "No final phrase was recognized. Replay your recording or try again in a quieter place.")
        }
        guard isKana(reading) else {
            return result(.inconclusive, "A supplied kana reading is needed to align this phrase. Choose an item with a supplied reading.")
        }
        guard !target.isIsolatedSound, reading.count > 1 else {
            return result(.inconclusive, "An isolated sound does not give reliable phrase evidence. Listen and replay, or practice a supplied whole word.")
        }
        let written = [target.prompt] + target.acceptedWrittenForms
        if written.contains(where: { normalized($0) == heard }) || heard == reading {
            return result(.match, "The recognizer heard the expected phrase. Homophones can share a reading; this is transcript evidence only.")
        }
        guard isKana(heard), isKana(reading) else {
            return result(.inconclusive, "The recognized spelling has no supplied reading alignment. Compare the visible text and replay your recording.")
        }
        return result(.different, "The recognizer heard a different phrase. Listen to the supplied reading and try again; recognition can make mistakes.")
    }

    public static func normalized(_ value: String) -> String {
        let normalized = value.precomposedStringWithCanonicalMapping
        let ignored = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return String(String.UnicodeScalarView(normalized.unicodeScalars.compactMap { scalar in
            if ignored.contains(scalar) { return nil }
            if (0x30A1...0x30F6).contains(scalar.value) { return UnicodeScalar(scalar.value - 0x60) }
            return scalar
        }))
    }

    private static func isKana(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy { (0x3041...0x3096).contains($0.value) || $0.value == 0x30FC || (0x309D...0x309E).contains($0.value) }
    }
}
