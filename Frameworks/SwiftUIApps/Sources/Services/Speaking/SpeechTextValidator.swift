import Foundation

struct SpeechTextValidator {
    static func normalizedReading(_ reading: String) -> String? {
        let trimmed = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { return nil }
        // Bundled kanji readings use these separators for stems and reading alternatives.
        let text = trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "-", with: "").precomposedStringWithCanonicalMapping
        var hasKana = false
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3041...0x3096, 0x30A1...0x30FA: hasKana = true
            case 0x30FC, 0x309D...0x309E, 0x30FD...0x30FE: break
            default:
                guard CharacterSet.whitespacesAndNewlines.contains(scalar) || "、。！？「」『』（）・…!?".unicodeScalars.contains(scalar) else { return nil }
            }
        }
        return hasKana ? text : nil
    }
}
