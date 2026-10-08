import Foundation

public struct DictionaryForm: Codable, Equatable, Sendable {
    public let text: String
    public let notes: [String]
    public let common: Bool

    public init(text: String, notes: [String] = [], common: Bool = false) {
        self.text = text
        self.notes = notes
        self.common = common
    }
}

public struct DictionaryReading: Codable, Equatable, Sendable {
    public let text: String
    public let spellings: [String]
    public let notes: [String]
    public let common: Bool
    public let kanaOnly: Bool

    public init(text: String, spellings: [String] = [], notes: [String] = [], common: Bool = false, kanaOnly: Bool = false) {
        self.text = text
        self.spellings = spellings
        self.notes = notes
        self.common = common
        self.kanaOnly = kanaOnly
    }
}

public struct DictionarySense: Codable, Equatable, Sendable {
    public let meanings: [String]
    public let pos: [String]
    public let labels: [String]
    public let notes: [String]
    public let spellings: [String]
    public let readings: [String]

    public init(meanings: [String], pos: [String] = [], labels: [String] = [], notes: [String] = [], spellings: [String] = [], readings: [String] = []) {
        self.meanings = meanings
        self.pos = pos
        self.labels = labels
        self.notes = notes
        self.spellings = spellings
        self.readings = readings
    }
}

public struct DictionaryWord: Codable, Equatable, Sendable {
    public let id: String
    public let jmdictID: Int
    public let headword: String
    public let reading: String
    public let level: String
    public let studyMeanings: [String]
    public let forms: [DictionaryForm]
    public let readings: [DictionaryReading]
    public let senses: [DictionarySense]

    public init(id: String, jmdictID: Int, headword: String, reading: String, level: String, studyMeanings: [String], forms: [DictionaryForm] = [], readings: [DictionaryReading], senses: [DictionarySense]) {
        self.id = id
        self.jmdictID = jmdictID
        self.headword = headword
        self.reading = reading
        self.level = level
        self.studyMeanings = studyMeanings
        self.forms = forms
        self.readings = readings
        self.senses = senses
    }
}

public struct DictionaryCatalog: Codable, Equatable, Sendable {
    public let version: Int
    public let created: String
    public let jmdictCreated: String
    public let entries: [DictionaryWord]
    public let legacyMap: [String?]

    public init(version: Int = 2, created: String, jmdictCreated: String, entries: [DictionaryWord], legacyMap: [String?] = []) {
        self.version = version
        self.created = created
        self.jmdictCreated = jmdictCreated
        self.entries = entries
        self.legacyMap = legacyMap
    }
}
