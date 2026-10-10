import Foundation
import SwiftData

public protocol PassageWordRepository {
    func save(catalogID: String, passageID: String, title: String) throws -> SavedStudyID
    func list(passageID: String) throws -> StudyList?
}

public final class StandardPassageWordRepository: PassageWordRepository {
    private let store: StudyStore
    private let catalog: VocabularyCatalogRepository?
    private let prepare: () throws -> Void
    private let saveContext: (ModelContext) throws -> Void
    private let makeID: () -> String
    private let now: () -> Date
    public init(store: StudyStore, catalog: VocabularyCatalogRepository? = nil, prepare: @escaping () throws -> Void = {}, save: @escaping (ModelContext) throws -> Void = { try $0.save() }, makeID: @escaping () -> String = { UUID().uuidString }, now: @escaping () -> Date = Date.init) {
        self.store = store; self.catalog = catalog; self.prepare = prepare; saveContext = save; self.makeID = makeID; self.now = now
    }
    public func list(passageID: String) throws -> StudyList? {
        try prepare()
        let key = try sourceKey(passageID)
        let context = store.makeContext()
        guard let list = try context.fetch(FetchDescriptor<StudyListModel>()).first(where: { $0.sourceKey == key }) else { return nil }
        let modern = try context.fetch(FetchDescriptor<StudyItemMembershipModel>()).filter { $0.listID == list.id }.map { $0.value.id }
        let legacy = try context.fetch(FetchDescriptor<StudyListMembershipModel>()).filter { $0.listID == list.id }.map { SavedStudyID(kind: .word, id: $0.wordID) }
        return list.value(wordCount: Set(modern + legacy).count)
    }
    public func save(catalogID: String, passageID: String, title: String) throws -> SavedStudyID {
        try prepare()
        let sourceKey = try sourceKey(passageID)
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = now()
        guard !title.isEmpty, title.count <= 20_000, date.timeIntervalSince1970.isFinite else { throw StudyListError.invalidIdentity }
        let catalog = try self.catalog ?? VocabularyCatalogRepository.bundled()
        guard let index = catalog.catalog.entries.firstIndex(where: { $0.id == catalogID }) else { throw BackupError.invalid("passage vocabulary identity") }
        let entry = catalog.catalog.entries[index]
        let context = store.makeContext()
        do {
            _ = try migrateStudyMemberships(context: context)
            let saved = try context.fetch(FetchDescriptor<KotobaDataModel>())
            let wordID: String
            // Old imports can retain more than one saved row for a catalog sense; keep the earliest learner identity.
            let matching = saved.filter { $0.catalogID == catalogID }.sorted {
                let left = $0.dateAdded ?? .distantPast, right = $1.dateAdded ?? .distantPast
                return left == right ? $0.id < $1.id : left < right
            }
            if let existing = matching.first { wordID = existing.id }
            else {
                let rows = try context.fetch(FetchDescriptor<WordsProgressModel>())
                guard rows.count == 1, let progress = rows.first, progress.catalogVersion == 2,
                      (0...catalog.catalog.entries.count).contains(progress.kotobaIndex), progress.kotobaProgress >= 0, progress.kotobaProgress < Int.max,
                      let level = KotobaDataModel.Level(rawValue: entry.level) else { throw BackupError.invalid("passage vocabulary progress") }
                wordID = makeID()
                guard !wordID.isEmpty, !saved.contains(where: { $0.id == wordID }) else { throw StudyListError.invalidIdentity }
                context.insert(KotobaDataModel(id: wordID, kanji: entry.headword, furigana: entry.reading, english: entry.studyMeanings.map { ArrayString(value: $0) }, jlptLevel: level, dateAdded: date, addedIndex: index, catalogID: catalogID))
                progress.kotobaProgress += 1
                progress.lastKotobaUpdated = date
            }
            let lists = try context.fetch(FetchDescriptor<StudyListModel>())
            let list: StudyListModel
            if let existing = lists.first(where: { $0.sourceKey == sourceKey }) { list = existing }
            else {
                let id = makeID()
                guard !id.isEmpty, !lists.contains(where: { $0.id == id }) else { throw StudyListError.invalidIdentity }
                let baseName = String(title.prefix(60))
                var name = baseName, suffix = 2
                let names = Set(lists.map(\.normalizedName))
                while names.contains(StudyListModel.normalize(name)) {
                    let ending = " (\(suffix))"
                    name = String(baseName.prefix(60 - ending.count)) + ending; suffix += 1
                }
                list = StudyListModel(id: id, name: name, createdAt: date, sourceKey: sourceKey)
                context.insert(list)
            }
            let id = SavedStudyID(kind: .word, id: wordID)
            let memberships = try context.fetch(FetchDescriptor<StudyItemMembershipModel>())
            if !memberships.contains(where: { $0.listID == list.id && $0.value.id == id }) { context.insert(StudyItemMembershipModel(listID: list.id, id: id)) }
            try saveContext(context); store.refreshContext()
            return id
        } catch { context.rollback(); throw error }
    }
    private func sourceKey(_ passageID: String) throws -> String {
        guard !passageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, passageID.count <= 248 else { throw StudyListError.invalidIdentity }
        return "passage:\(passageID)"
    }
}
