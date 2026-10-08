import Foundation
import SwiftData

public struct SavedStudyItem: Hashable {
    public let id: SavedStudyID
    public let headword: String
    public let reading: String?
    public let meanings: [String]
    public let level: String
    public let onyomi: [String]
    public let kunyomi: [String]
    public let strokes: Int?
    public let dateAdded: Date?
    public let addedIndex: Int?
    public let exampleWordKey: ExampleWordKey?

    init(word: KotobaDataModel) {
        exampleWordKey = ExampleWordKey(headword: word.kanji.isEmpty ? word.furigana : word.kanji, reading: word.furigana, level: word.jlptLevel.rawValue)
        id = SavedStudyID(kind: .word, id: word.id)
        headword = word.kanji.isEmpty ? word.furigana : word.kanji
        reading = word.furigana == headword || word.furigana.isEmpty ? nil : word.furigana
        meanings = word.english.map(\.value)
        level = word.jlptLevel.rawValue
        onyomi = []
        kunyomi = []
        strokes = nil
        dateAdded = word.dateAdded
        addedIndex = word.addedIndex
    }
    init(kanji: KanjiDataModel) {
        exampleWordKey = nil
        id = SavedStudyID(kind: .kanji, id: kanji.id)
        headword = kanji.kanji
        reading = nil
        meanings = kanji.meanings.map(\.value)
        level = kanji.jlptLevel.rawValue
        onyomi = kanji.onyomi.map(\.value)
        kunyomi = kanji.kunyomi.map(\.value)
        strokes = kanji.stroke > 0 ? kanji.stroke : nil
        dateAdded = kanji.dateAdded
        addedIndex = kanji.addedIndex
    }
}

public enum ReviewStoreError: Error {
    case invalidRecord
}

public protocol ReviewRepository {
    func savedItems(kind: SavedStudyKind) throws -> [SavedStudyItem]
    func records() throws -> [ReviewRecord]
    func save(_ record: ReviewRecord) throws
    func save(_ record: ReviewRecord, activity: PracticeActivity?) throws
}

public final class StandardReviewRepository: ReviewRepository {
    private let contextProvider: () -> ModelContext
    private let saveContext: (ModelContext) throws -> Void
    private let refreshContext: () -> Void

    public init(context: ModelContext, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        contextProvider = { context }
        refreshContext = {}
        saveContext = save
    }
    public init(store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        contextProvider = { store.makeContext() }
        refreshContext = { store.refreshContext() }
        saveContext = save
    }

    public func savedItems(kind: SavedStudyKind) throws -> [SavedStudyItem] {
        let context = contextProvider()
        switch kind {
        case .word: return try context.fetch(FetchDescriptor<KotobaDataModel>()).map(SavedStudyItem.init(word:))
        case .kanji: return try context.fetch(FetchDescriptor<KanjiDataModel>()).map(SavedStudyItem.init(kanji:))
        }
    }

    public func records() throws -> [ReviewRecord] {
        try contextProvider().fetch(FetchDescriptor<ReviewRecordModel>()).map(\.value)
            .sorted { $0.id.key < $1.id.key }
    }

    public func save(_ record: ReviewRecord) throws {
        try save(record, activity: nil)
    }

    public func save(_ record: ReviewRecord, activity: PracticeActivity?) throws {
        if let activity {
            try BackupValidator.validateActivity(activity)
            guard activity.studyID == record.id else { throw ReviewStoreError.invalidRecord }
        }
        guard (0...4).contains(record.stage), record.sessionBaselineStage.map({ (0...4).contains($0) }) ?? true,
              !record.id.id.isEmpty, record.dueDate.timeIntervalSince1970.isFinite,
              record.lastReviewedAt.timeIntervalSince1970.isFinite else { throw ReviewStoreError.invalidRecord }
        let context = contextProvider()
        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }
        do {
            try requireSavedItem(record.id, context: context)
            let key = record.id.key
            let descriptor = FetchDescriptor<ReviewRecordModel>(predicate: #Predicate { $0.key == key })
            if let model = try context.fetch(descriptor).first {
                model.apply(record)
            } else {
                context.insert(ReviewRecordModel(record: record))
            }
            if let activity { try insertPracticeActivityIfNeeded(activity, context: context) }
            try saveContext(context)
            refreshContext()
        } catch {
            context.rollback()
            throw error
        }
    }
}

func requireSavedItem(_ id: SavedStudyID, context: ModelContext) throws {
    let savedID = id.id
    let exists: Bool
    switch id.kind {
    case .word: exists = try !context.fetch(FetchDescriptor<KotobaDataModel>(predicate: #Predicate { $0.id == savedID })).isEmpty
    case .kanji: exists = try !context.fetch(FetchDescriptor<KanjiDataModel>(predicate: #Predicate { $0.id == savedID })).isEmpty
    }
    if !exists { throw DataError.dataNotFound }
}
