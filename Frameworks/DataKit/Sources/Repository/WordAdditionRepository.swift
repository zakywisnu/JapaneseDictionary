import Foundation
import SwiftData

public enum WordAdditionSource {
    case next(expectedCursor: Int)
    case selected
}

public protocol WordAdditionRepository {
    func addWord(catalogID: String, savedID: String, addedAt: Date, source: WordAdditionSource) throws -> StudyProgress
}

public final class StandardWordAdditionRepository: WordAdditionRepository {
    private let store: StudyStore
    private let catalog: VocabularyCatalogRepository?
    private let prepare: () throws -> Void
    private let saveContext: (ModelContext) throws -> Void

    public init(store: StudyStore, catalog: VocabularyCatalogRepository? = nil,
                prepare: @escaping () throws -> Void = {},
                save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.store = store
        self.catalog = catalog
        self.prepare = prepare
        saveContext = save
    }

    public func addWord(catalogID: String, savedID: String, addedAt: Date, source: WordAdditionSource) throws -> StudyProgress {
        try prepare()
        let catalog = try self.catalog ?? VocabularyCatalogRepository.bundled()
        guard let index = catalog.catalog.entries.firstIndex(where: { $0.id == catalogID }),
              !savedID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              addedAt.timeIntervalSince1970.isFinite else { throw BackupError.invalid("word addition") }
        let entry = catalog.catalog.entries[index]
        let context = store.makeContext()
        do {
            let rows = try context.fetch(FetchDescriptor<WordsProgressModel>())
            guard rows.count == 1, let progress = rows.first, progress.catalogVersion == 2,
                  (0...catalog.catalog.entries.count).contains(progress.kotobaIndex),
                  progress.kotobaProgress >= 0, progress.kotobaProgress < Int.max else {
                throw BackupError.invalid("word addition progress")
            }
            let saved = try context.fetch(FetchDescriptor<KotobaDataModel>())
            let membership = Set(saved.compactMap(\.catalogID))
            switch source {
            case .selected:
                if membership.contains(catalogID) { return StudyProgress(progress) }
            case .next(let expectedCursor):
                guard expectedCursor == progress.kotobaIndex,
                      let firstUnsaved = catalog.catalog.entries.indices.dropFirst(expectedCursor).first(where: { !membership.contains(catalog.catalog.entries[$0].id) }),
                      firstUnsaved == index else { throw BackupError.invalid("stale sequential word addition") }
            }
            guard !saved.contains(where: { $0.id == savedID }),
                  let wordLevel = KotobaDataModel.Level(rawValue: entry.level),
                  let progressLevel = WordsProgressModel.Level(rawValue: entry.level) else {
                throw BackupError.invalid("word addition identity")
            }
            context.insert(KotobaDataModel(id: savedID, kanji: entry.headword, furigana: entry.reading,
                english: entry.studyMeanings.map { ArrayString(value: $0) }, jlptLevel: wordLevel,
                dateAdded: addedAt, addedIndex: index, catalogID: catalogID))
            progress.kotobaProgress += 1
            progress.lastKotobaUpdated = addedAt
            if case .next = source {
                progress.kotobaIndex = index + 1
                progress.kotobaLevel = progressLevel
            }
            try saveContext(context)
            store.refreshContext()
            return StudyProgress(progress)
        } catch {
            context.rollback()
            throw error
        }
    }
}
