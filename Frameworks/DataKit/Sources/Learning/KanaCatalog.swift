import Foundation

public enum KanaScript: String, CaseIterable, Identifiable {
    case hiragana = "Hiragana", katakana = "Katakana"
    public var id: String { rawValue }
}

public enum KanaGroup: String, CaseIterable, Identifiable {
    case basic = "Basic", voiced = "Voiced", contracted = "Contracted", marks = "Small kana and marks"
    public var id: String { rawValue }
}

public struct KanaEntry: Identifiable, Hashable {
    public let script: KanaScript
    public let group: KanaGroup
    public let kana: String
    public let romanization: String
    public let note: String
    public let reading: String?
    public var id: String { script.rawValue + ":" + kana }
    public func material(now: Date = Date()) -> StudyMaterial {
        .init(id: UUID().uuidString, kind: .customCard, prompt: kana, answer: romanization,
              reading: reading, notes: note, category: "kana", createdAt: now, updatedAt: now)
    }
}

public enum KanaCatalog {
    public static let entries: [KanaEntry] = {
        let basics = "あ:a い:i う:u え:e お:o か:ka き:ki く:ku け:ke こ:ko さ:sa し:shi す:su せ:se そ:so た:ta ち:chi つ:tsu て:te と:to な:na に:ni ぬ:nu ね:ne の:no は:ha ひ:hi ふ:fu へ:he ほ:ho ま:ma み:mi む:mu め:me も:mo や:ya ゆ:yu よ:yo ら:ra り:ri る:ru れ:re ろ:ro わ:wa を:wo ん:n"
        let voiced = "が:ga ぎ:gi ぐ:gu げ:ge ご:go ざ:za じ:ji ず:zu ぜ:ze ぞ:zo だ:da ぢ:ji づ:zu で:de ど:do ば:ba び:bi ぶ:bu べ:be ぼ:bo ぱ:pa ぴ:pi ぷ:pu ぺ:pe ぽ:po ゔ:vu"
        let stems = [("き", "ky"), ("し", "sh"), ("ち", "ch"), ("に", "ny"), ("ひ", "hy"), ("み", "my"), ("り", "ry"), ("ぎ", "gy"), ("じ", "j"), ("び", "by"), ("ぴ", "py")]
        let contracted = stems.flatMap { kana, roman in [("ゃ", "a"), ("ゅ", "u"), ("ょ", "o")].map { kana + $0.0 + ":" + roman + $0.1 } }.joined(separator: " ")
        var result: [KanaEntry] = []
        for script in KanaScript.allCases {
            for (group, text) in [(KanaGroup.basic, basics), (.voiced, voiced), (.contracted, contracted)] {
                for token in text.split(separator: " ") {
                    let parts = token.split(separator: ":").map(String.init)
                    let hira = parts[0]
                    let kana = script == .hiragana ? hira : katakana(hira)
                    var note = "Hepburn-style romanization. Japanese vowels are short and steady; roman letters are a reading guide."
                    switch hira {
                    case "し": note = "Written shi in Hepburn; si in some other systems. The sound is not English see."
                    case "ち": note = "Written chi in Hepburn; ti in some other systems."
                    case "つ": note = "Written tsu in Hepburn; tu in some other systems. Begin with a ts sound."
                    case "ふ": note = "Written fu in Hepburn; hu in some other systems. The consonant uses both lips, unlike English f."
                    case "は": note = "Normally ha. As the topic particle は, pronounced wa."
                    case "へ": note = "Normally he. As the direction particle へ, pronounced e."
                    case "を": note = "Romanized wo to identify the kana; the object particle is normally pronounced o."
                    case "じ", "ぢ": note = "Usually pronounced ji in modern standard Japanese. じ and ぢ share this sound; spelling depends on the word. Some systems write ぢ as di or dji."
                    case "ず", "づ": note = "Usually pronounced zu in modern standard Japanese. ず and づ share this sound; spelling depends on the word. Some systems write づ as du or dzu."
                    case "ゔ": note = "Used mainly as ヴ in katakana loanwords for v-like sounds. Many speakers pronounce it like b; hiragana ゔ is uncommon."
                    case "ん": note = "The moraic nasal n changes sound with surrounding consonants. It takes its own beat."
                    default: if group == .contracted { note = "The second kana is small. Read both together as one beat, unlike a full-size や, ゆ or よ." }
                    }
                    result.append(.init(script: script, group: group, kana: kana, romanization: parts[1], note: note, reading: hira == "を" ? "お" : kana))
                }
            }
            result.append(.init(script: script, group: .marks, kana: script == .hiragana ? "っ" : "ッ", romanization: "Small tsu: consonant pause", note: "A small tsu adds one beat of closure before the next consonant, as in きって (kitte). It is not a standalone tsu sound.", reading: nil))
            if script == .katakana { result.append(.init(script: script, group: .marks, kana: "ー", romanization: "Long vowel mark", note: "Extend the preceding vowel by one beat, as in コーヒー (kōhī). This mark has no standalone reading.", reading: nil)) }
        }
        return result
    }()

    private static func katakana(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.map { UnicodeScalar($0.value + 0x60)! }))
    }
}

/// Match content rather than generated IDs so edited cards and unrelated categories keep their identity.
public struct KanaCardSaver {
    private let load: () throws -> [StudyMaterial]
    private let save: (StudyMaterial) throws -> StudyMaterial
    public init(load: @escaping () throws -> [StudyMaterial], save: @escaping (StudyMaterial) throws -> StudyMaterial) {
        self.load = load; self.save = save
    }
    public func saveSelection(_ entries: [KanaEntry]) throws -> [StudyMaterial] {
        var saved = try load()
        var result: [StudyMaterial] = []
        for entry in entries {
            let existing = saved.first { $0.kind == .customCard && $0.category == "kana" && $0.prompt == entry.kana && $0.answer == entry.romanization }
            let value: StudyMaterial
            if let existing { value = existing }
            else { value = try save(entry.material()); saved.append(value) }
            if !result.contains(where: { $0.id == value.id }) { result.append(value) }
        }
        return result
    }
}
