import Foundation

public struct BackupWord: Codable, Equatable {
    public var id: String
    public var kanji: String
    public var furigana: String
    public var english: [String]
    public var jlptLevel: KotobaDataModel.Level
    public var dateAdded: Date?
    public var addedIndex: Int?
    public var memoryAid: MemoryAidSuggestion?
    public var catalogID: String?
    public init(id: String, kanji: String, furigana: String, english: [String], jlptLevel: KotobaDataModel.Level, dateAdded: Date?, addedIndex: Int?, memoryAid: MemoryAidSuggestion? = nil, catalogID: String? = nil) {
        self.id = id
        self.kanji = kanji
        self.furigana = furigana
        self.english = english
        self.jlptLevel = jlptLevel
        self.dateAdded = dateAdded
        self.addedIndex = addedIndex
        self.memoryAid = memoryAid
        self.catalogID = catalogID
    }
    init(_ model: KotobaDataModel) {
        self.init(id: model.id, kanji: model.kanji, furigana: model.furigana, english: model.english.map(\.value), jlptLevel: model.jlptLevel, dateAdded: model.dateAdded, addedIndex: model.addedIndex, memoryAid: Self.memoryAid(model), catalogID: model.catalogID)
    }
    private static func memoryAid(_ model: KotobaDataModel) -> MemoryAidSuggestion? {
        guard model.memoryExplanation != nil || model.memoryMnemonic != nil else { return nil }
        // Keep partial stored advice invalid so export rejects it instead of discarding it.
        return .init(explanation: model.memoryExplanation ?? "", mnemonic: model.memoryMnemonic ?? "")
    }
    var model: KotobaDataModel {
        KotobaDataModel(id: id, kanji: kanji, furigana: furigana, english: english.map { ArrayString(value: $0) }, jlptLevel: jlptLevel, dateAdded: dateAdded, addedIndex: addedIndex, memoryExplanation: memoryAid?.explanation, memoryMnemonic: memoryAid?.mnemonic, catalogID: catalogID)
    }
}

public struct BackupKanji: Codable, Equatable {
    public var id: String
    public var kanji: String
    public var stroke: Int
    public var onyomi: [String]
    public var kunyomi: [String]
    public var jlptLevel: KanjiDataModel.Level
    public var meanings: [String]
    public var dateAdded: Date?
    public var addedIndex: Int?
    public init(id: String, kanji: String, stroke: Int, onyomi: [String], kunyomi: [String], jlptLevel: KanjiDataModel.Level, meanings: [String], dateAdded: Date?, addedIndex: Int?) {
        self.id = id
        self.kanji = kanji
        self.stroke = stroke
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.jlptLevel = jlptLevel
        self.meanings = meanings
        self.dateAdded = dateAdded
        self.addedIndex = addedIndex
    }
    init(_ model: KanjiDataModel) {
        self.init(id: model.id, kanji: model.kanji, stroke: model.stroke, onyomi: model.onyomi.map(\.value), kunyomi: model.kunyomi.map(\.value), jlptLevel: model.jlptLevel, meanings: model.meanings.map(\.value), dateAdded: model.dateAdded, addedIndex: model.addedIndex)
    }
    var model: KanjiDataModel {
        KanjiDataModel(id: id, kanji: kanji, stroke: stroke, onyomi: onyomi.map { ArrayString(value: $0) }, kunyomi: kunyomi.map { ArrayString(value: $0) }, jlptLevel: jlptLevel, meanings: meanings.map { ArrayString(value: $0) }, dateAdded: dateAdded, addedIndex: addedIndex)
    }
}

public struct BackupProgress: Codable, Equatable {
    public var id: String
    public var kanjiProgress: Int
    public var kotobaProgress: Int
    public var kanjiLevel: WordsProgressModel.Level
    public var kotobaLevel: WordsProgressModel.Level
    public var kanjiIndex: Int
    public var kotobaIndex: Int
    public var lastKotobaUpdated: Date
    public var lastKanjiUpdated: Date
    public var catalogVersion: Int?
    public init(id: String, kanjiProgress: Int, kotobaProgress: Int, kanjiLevel: WordsProgressModel.Level, kotobaLevel: WordsProgressModel.Level, kanjiIndex: Int, kotobaIndex: Int, lastKotobaUpdated: Date, lastKanjiUpdated: Date, catalogVersion: Int? = nil) {
        self.id = id
        self.kanjiProgress = kanjiProgress
        self.kotobaProgress = kotobaProgress
        self.kanjiLevel = kanjiLevel
        self.kotobaLevel = kotobaLevel
        self.kanjiIndex = kanjiIndex
        self.kotobaIndex = kotobaIndex
        self.lastKotobaUpdated = lastKotobaUpdated
        self.lastKanjiUpdated = lastKanjiUpdated
        self.catalogVersion = catalogVersion
    }
    init(_ model: WordsProgressModel) {
        self.init(id: model.id, kanjiProgress: model.kanjiProgress, kotobaProgress: model.kotobaProgress, kanjiLevel: model.kanjiLevel, kotobaLevel: model.kotobaLevel, kanjiIndex: model.kanjiIndex, kotobaIndex: model.kotobaIndex, lastKotobaUpdated: model.lastKotobaUpdated, lastKanjiUpdated: model.lastKanjiUpdated, catalogVersion: model.catalogVersion)
    }
    var model: WordsProgressModel {
        WordsProgressModel(id: id, kanjiProgress: kanjiProgress, kotobaProgress: kotobaProgress, kanjiLevel: kanjiLevel, kotobaLevel: kotobaLevel, kanjiIndex: kanjiIndex, kotobaIndex: kotobaIndex, lastKotobaUpdated: lastKotobaUpdated, lastKanjiUpdated: lastKanjiUpdated, catalogVersion: catalogVersion)
    }
}

public enum BackupStudyKind: String, Codable, Equatable {
    case words, kanji
}

public struct BackupPreferences: Codable, Equatable {
    public var todayKind: BackupStudyKind
    public var collectionKind: BackupStudyKind
    public init(todayKind: BackupStudyKind = .words, collectionKind: BackupStudyKind = .words) {
        self.todayKind = todayKind
        self.collectionKind = collectionKind
    }
}

public struct StudyBackup: Codable, Equatable {
    public var formatVersion: Int
    public var createdAt: Date
    public var catalogFingerprint: String
    public var words: [BackupWord]
    public var kanjis: [BackupKanji]
    public var progress: BackupProgress?
    public var reviews: [ReviewRecord]
    public var preferences: BackupPreferences

    public init(formatVersion: Int = 1, createdAt: Date, catalogFingerprint: String, words: [BackupWord], kanjis: [BackupKanji], progress: BackupProgress?, reviews: [ReviewRecord], preferences: BackupPreferences) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.catalogFingerprint = catalogFingerprint
        self.words = words
        self.kanjis = kanjis
        self.progress = progress
        self.reviews = reviews
        self.preferences = preferences
    }
}
