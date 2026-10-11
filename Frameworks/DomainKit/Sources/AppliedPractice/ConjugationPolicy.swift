import DataKit

public enum ConjugationPolicy {
    public static let classes = ["godan", "ichidan", "irregular", "iAdjective", "naAdjective"]
    public static let forms = ["polite", "politeNegative", "plainNegative", "plainPast", "te", "connective"]
    public static func matches(_ input: String, accepted: [String]) -> Bool {
        ExerciseAnswerNormalizer.matches(input, accepted: accepted, kind: .conjugation)
    }
    public static func classLabel(_ id: String) -> String {
        switch id {
        case "godan": return "Godan verbs"
        case "ichidan": return "Ichidan verbs"
        case "irregular": return "Irregular verbs"
        case "iAdjective": return "い adjectives"
        case "naAdjective": return "な adjectives"
        default: return "All classes"
        }
    }
    public static func formLabel(_ id: String) -> String {
        switch id {
        case "polite": return "Polite affirmative"
        case "politeNegative": return "Polite negative"
        case "plainNegative": return "Plain negative"
        case "plainPast": return "Plain past"
        case "te": return "て form"
        case "connective": return "Connective て / で"
        default: return "All forms"
        }
    }
}
