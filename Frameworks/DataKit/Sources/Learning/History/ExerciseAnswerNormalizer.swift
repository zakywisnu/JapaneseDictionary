import Foundation

public enum ExerciseAnswerNormalizer {
    public static func normalized(_ text: String, kind: ExerciseQuestionKind) -> String {
        let width = text.folding(options: .widthInsensitive, locale: Locale(identifier: "ja_JP"))
        let composed = width.precomposedStringWithCanonicalMapping
        let spaced = composed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        switch kind {
        case .kanaReading, .listeningReading:
            return (spaced.applyingTransform(.hiraganaToKatakana, reverse: true) ?? spaced).precomposedStringWithCanonicalMapping
        default: return spaced.lowercased()
        }
    }
    public static func matches(_ input: String, accepted: [String], kind: ExerciseQuestionKind) -> Bool {
        guard input.count <= 500, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return accepted.contains { normalized($0, kind: kind) == normalized(input, kind: kind) }
    }
}
