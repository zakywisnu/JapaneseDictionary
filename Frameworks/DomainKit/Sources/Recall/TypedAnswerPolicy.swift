import Foundation
import DataKit

public enum TypedAnswerMode { case kanaReading, romanization }
public enum TypedAnswerResult: Equatable { case match, different, empty }
public enum TypedAnswerPolicy {
    public static func evaluate(input: String, accepted: [String], mode: TypedAnswerMode) -> TypedAnswerResult {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        let kind: ExerciseQuestionKind = mode == .kanaReading ? .kanaReading : .romanization
        return ExerciseAnswerNormalizer.matches(input, accepted: accepted, kind: kind) ? .match : .different
    }
    public static func romanizationAliases(for entry: KanaEntry) -> [String] {
        let kana = ExerciseAnswerNormalizer.normalized(entry.kana, kind: .kanaReading)
        let aliases = ["し": "si", "ち": "ti", "つ": "tu", "ふ": "hu"]
        return [entry.romanization] + (aliases[kana].map { [$0] } ?? [])
    }
}
