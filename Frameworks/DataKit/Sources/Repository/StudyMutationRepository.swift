import Foundation
import SwiftData

public struct StudyProgress: Equatable {
    public let id: String
    public let kanjiProgress: Int
    public let kotobaProgress: Int
    public let kanjiLevel: String
    public let kotobaLevel: String
    public let kanjiIndex: Int
    public let kotobaIndex: Int
    public let lastKotobaUpdated: Date
    public let lastKanjiUpdated: Date

    init(_ model: WordsProgressModel) {
        id = model.id
        kanjiProgress = model.kanjiProgress
        kotobaProgress = model.kotobaProgress
        kanjiLevel = model.kanjiLevel.rawValue
        kotobaLevel = model.kotobaLevel.rawValue
        kanjiIndex = model.kanjiIndex
        kotobaIndex = model.kotobaIndex
        lastKotobaUpdated = model.lastKotobaUpdated
        lastKanjiUpdated = model.lastKanjiUpdated
    }
}

public protocol StudyMutationRepository {
    func delete(id: SavedStudyID) throws -> StudyProgress
}

public final class StandardStudyMutationRepository: StudyMutationRepository {
    private let contextProvider: () -> ModelContext
    private let saveContext: (ModelContext) throws -> Void

    public init(context: ModelContext, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        contextProvider = { context }
        saveContext = save
    }
    public init(store: StudyStore, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        contextProvider = { store.context }
        saveContext = save
    }

    public func delete(id: SavedStudyID) throws -> StudyProgress {
        let context = contextProvider()
        let previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = previousAutosave }
        do {
            guard let progress = try context.fetch(FetchDescriptor<WordsProgressModel>()).first else { throw DataError.dataNotFound }
            let savedID = id.id
            switch id.kind {
            case .word:
                guard let word = try context.fetch(FetchDescriptor<KotobaDataModel>(predicate: #Predicate { $0.id == savedID })).first else { throw DataError.dataNotFound }
                progress.kotobaProgress -= 1
                progress.kotobaIndex = word.addedIndex ?? 0
                progress.kotobaLevel = .init(rawValue: max(progress.kotobaLevel.rawValue, word.jlptLevel.rawValue)) ?? .n5
                context.delete(word)
            case .kanji:
                guard let kanji = try context.fetch(FetchDescriptor<KanjiDataModel>(predicate: #Predicate { $0.id == savedID })).first else { throw DataError.dataNotFound }
                progress.kanjiProgress -= 1
                progress.kanjiIndex = kanji.addedIndex ?? 0
                progress.kanjiLevel = .init(rawValue: max(progress.kanjiLevel.rawValue, kanji.jlptLevel.rawValue)) ?? .n5
                context.delete(kanji)
            }
            let key = id.key
            for record in try context.fetch(FetchDescriptor<ReviewRecordModel>(predicate: #Predicate { $0.key == key })) {
                context.delete(record)
            }
            try saveContext(context)
            return StudyProgress(progress)
        } catch {
            context.rollback()
            throw error
        }
    }
}
