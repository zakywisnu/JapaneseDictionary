import Foundation
import DataKit

public struct ReviewSession: Hashable {
    var kind: StudyKind? = nil
    let items: [ReviewItem]
    var origin: ReviewOrigin = .today
    var id: UUID = UUID()

    var noun: String {
        let kinds = Set(items.map { $0.compositeID.kind })
        if kinds.count > 1 { return "item" }
        let selected = kinds.first ?? kind?.savedKind
        return selected == .word ? "word" : selected == .kanji ? "kanji" : "item"
    }
    var nouns: String { noun.pluralNoun }
}

enum ReviewOrigin: Hashable {
    case today
    case collection
    case due
    case difficult

    case list(id: String, name: String)

    var backTitle: String {
        switch self {
        case .collection: return "Back to Collection"
        case .list(_, let name): return "Back to \(name)"
        case .today, .due: return "Back to Today"
        case .difficult: return "Back to practice setup"
        }
    }
    var completionContext: String {
        switch self {
        case .today: return "added today"
        case .due: return "due for review"
        case .difficult: return "from difficult practice"
        case .collection: return "from your collection"
        case .list(_, let name): return "from \(name)"
        }
    }
    var emptyMessage: String {
        switch self {
        case .collection: return "Return to Collection and choose another level."
        case .list: return "Return to your list and choose another level or organize more saved items."
        case .today, .due: return "Return to Today and add an item or check what is due."
        case .difficult: return "Return to practice setup and choose another filter."
        }
    }
}

struct ReviewSelection {
    var level: String?
    var limit: Int?

    func selected(_ items: [ReviewItem]) -> [ReviewItem] {
        let ordered = items.filter { level == nil || $0.level == level }.sorted {
            let lhs = $0.dateAdded ?? .distantPast
            let rhs = $1.dateAdded ?? .distantPast
            return lhs == rhs ? $0.compositeID.key < $1.compositeID.key : lhs > rhs
        }
        return limit.map { Array(ordered.prefix(max(0, $0))) } ?? ordered
    }
}

struct ReviewItem: Hashable {
    let compositeID: SavedStudyID
    let material: StudyMaterial?
    var savedID: String { compositeID.id }
    let dateAdded: Date?
    let headword: String
    let reading: String?
    let meanings: [String]
    let level: String
    let onyomi: [String]
    let kunyomi: [String]
    let strokes: Int?
    let exampleWordKey: ExampleWordKey?

    var spokenReadings: [String] {
        if let material { return material.reading.map { [$0] } ?? [] }
        if let key = exampleWordKey { return [key.reading] }
        return onyomi + kunyomi
    }

    init(saved: SavedStudyItem) {
        compositeID = saved.id
        material = saved.material
        dateAdded = saved.dateAdded
        headword = saved.headword
        reading = saved.reading
        meanings = saved.meanings
        level = saved.level
        onyomi = saved.onyomi
        kunyomi = saved.kunyomi
        strokes = saved.strokes
        exampleWordKey = saved.exampleWordKey
    }

    init(material: StudyMaterial) { self.init(saved: SavedStudyItem(material: material)) }

    init(word: Kotoba) {
        exampleWordKey = ExampleWordKey(headword: word.kanji.isEmpty ? word.furigana : word.kanji, reading: word.furigana, level: word.jlptLevel.rawValue)
        compositeID = SavedStudyID(kind: .word, id: word.id)
        material = nil
        dateAdded = word.dateAdded
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
        exampleWordKey = nil
        compositeID = SavedStudyID(kind: .kanji, id: kanji.id)
        material = nil
        dateAdded = kanji.dateAdded
        headword = kanji.kanji
        reading = nil
        meanings = kanji.meanings
        level = kanji.jlptLevel.rawValue
        onyomi = kanji.onyomi
        kunyomi = kanji.kunyomi
        strokes = kanji.stroke > 0 ? kanji.stroke : nil
    }
}
