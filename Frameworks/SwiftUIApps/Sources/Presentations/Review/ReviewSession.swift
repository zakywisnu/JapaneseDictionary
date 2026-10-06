import Foundation

public struct ReviewSession: Hashable {
    let kind: StudyKind
    let items: [ReviewItem]

    var noun: String { kind == .words ? "word" : "kanji" }
    var nouns: String { noun.pluralNoun }
}

struct ReviewItem: Hashable {
    let headword: String
    let reading: String?
    let meanings: [String]
    let level: String
    let onyomi: [String]
    let kunyomi: [String]
    let strokes: Int?

    init(word: Kotoba) {
        let entry = word.studyEntry
        headword = entry.headword
        reading = entry.reading
        meanings = word.english
        level = entry.level
        onyomi = []
        kunyomi = []
        strokes = nil
    }

    init(kanji: Kanji) {
        headword = kanji.kanji
        reading = nil
        meanings = kanji.meanings
        level = kanji.jlptLevel.rawValue
        onyomi = kanji.onyomi
        kunyomi = kanji.kunyomi
        strokes = kanji.stroke > 0 ? kanji.stroke : nil
    }
}
