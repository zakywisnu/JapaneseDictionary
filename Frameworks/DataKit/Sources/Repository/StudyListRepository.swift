import Foundation
import SwiftData

public enum StudyListError: Error, Equatable, LocalizedError {
    case invalidName, duplicateName, missingList, missingWord, invalidIdentity

    public var errorDescription: String? {
        switch self {
        case .invalidName: return "Enter a list name between 1 and 60 characters."
        case .duplicateName: return "A list with that name already exists. Choose another name."
        case .missingList: return "This list no longer exists. Return to Study lists."
        case .missingWord: return "This word is no longer in your collection. Add it before organizing it."
        case .invalidIdentity: return "The list could not be created. Try again."
        }
    }
}

public protocol StudyListRepository {
    func lists() throws -> [StudyList]
    func create(name: String) throws -> StudyList
    func rename(id: String, name: String) throws
    func delete(id: String) throws
    func words(listID: String) throws -> [SavedStudyItem]
    func listIDs(wordID: String) throws -> Set<String>
    func setLists(wordID: String, listIDs: Set<String>) throws
    func removeWord(listID: String, wordID: String) throws
}

public final class StandardStudyListRepository: StudyListRepository {
    private let store: StudyStore
    private let prepare: () throws -> Void
    private let saveContext: (ModelContext) throws -> Void
    private let makeID: () -> String
    private let now: () -> Date

    public init(store: StudyStore, prepare: @escaping () throws -> Void = {}, save: @escaping (ModelContext) throws -> Void = { try $0.save() }, makeID: @escaping () -> String = { UUID().uuidString }, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.prepare = prepare
        saveContext = save
        self.makeID = makeID
        self.now = now
    }

    public func lists() throws -> [StudyList] {
        let context = try context()
        let memberships = try context.fetch(FetchDescriptor<StudyListMembershipModel>())
        return try context.fetch(FetchDescriptor<StudyListModel>()).sorted {
            $0.normalizedName == $1.normalizedName ? $0.id < $1.id : $0.normalizedName < $1.normalizedName
        }.map { list in
            list.value(wordCount: Set(memberships.filter { $0.listID == list.id }.map(\.wordID)).count)
        }
    }

    public func create(name: String) throws -> StudyList {
        try mutate { context in
            let name = try validatedName(name, excluding: nil, context: context)
            let id = makeID()
            let createdAt = now()
            guard !id.isEmpty, createdAt.timeIntervalSince1970.isFinite,
                  try !context.fetch(FetchDescriptor<StudyListModel>()).contains(where: { $0.id == id }) else {
                throw StudyListError.invalidIdentity
            }
            let list = StudyListModel(id: id, name: name, createdAt: createdAt)
            context.insert(list)
            return list.value()
        }
    }

    public func rename(id: String, name: String) throws {
        try mutate { context in
            let list = try requireList(id, context: context)
            let name = try validatedName(name, excluding: id, context: context)
            list.name = name
            list.normalizedName = StudyListModel.normalize(name)
        }
    }

    public func delete(id: String) throws {
        try mutate { context in
            let list = try requireList(id, context: context)
            for membership in try context.fetch(FetchDescriptor<StudyListMembershipModel>()) where membership.listID == id {
                context.delete(membership)
            }
            context.delete(list)
        }
    }

    public func words(listID: String) throws -> [SavedStudyItem] {
        let context = try context()
        _ = try requireList(listID, context: context)
        let ids = Set(try context.fetch(FetchDescriptor<StudyListMembershipModel>()).filter { $0.listID == listID }.map(\.wordID))
        return try context.fetch(FetchDescriptor<KotobaDataModel>()).filter { ids.contains($0.id) }.map(SavedStudyItem.init(word:)).sorted {
            let lhs = $0.dateAdded ?? .distantPast
            let rhs = $1.dateAdded ?? .distantPast
            return lhs == rhs ? $0.id.id < $1.id.id : lhs > rhs
        }
    }

    public func listIDs(wordID: String) throws -> Set<String> {
        let context = try context()
        try requireWord(wordID, context: context)
        return Set(try context.fetch(FetchDescriptor<StudyListMembershipModel>()).filter { $0.wordID == wordID }.map(\.listID))
    }

    public func setLists(wordID: String, listIDs: Set<String>) throws {
        try mutate { context in
            try requireWord(wordID, context: context)
            for id in listIDs { _ = try requireList(id, context: context) }
            let memberships = try context.fetch(FetchDescriptor<StudyListMembershipModel>()).filter { $0.wordID == wordID }
            let existing = Set(memberships.map(\.listID))
            for membership in memberships where !listIDs.contains(membership.listID) { context.delete(membership) }
            for id in listIDs.subtracting(existing) {
                context.insert(StudyListMembershipModel(listID: id, wordID: wordID))
            }
        }
    }

    public func removeWord(listID: String, wordID: String) throws {
        try mutate { context in
            _ = try requireList(listID, context: context)
            try requireWord(wordID, context: context)
            for membership in try context.fetch(FetchDescriptor<StudyListMembershipModel>()) where membership.listID == listID && membership.wordID == wordID {
                context.delete(membership)
            }
        }
    }

    private func context() throws -> ModelContext {
        try prepare()
        return store.makeContext()
    }

    private func mutate<T>(_ action: (ModelContext) throws -> T) throws -> T {
        let context = try context()
        do {
            let result = try action(context)
            try saveContext(context)
            store.refreshContext()
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    private func validatedName(_ input: String, excluding id: String?, context: ModelContext) throws -> String {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...60).contains(name.count) else { throw StudyListError.invalidName }
        let normalized = StudyListModel.normalize(name)
        guard try !context.fetch(FetchDescriptor<StudyListModel>()).contains(where: { $0.id != id && $0.normalizedName == normalized }) else {
            throw StudyListError.duplicateName
        }
        return name
    }

    private func requireList(_ id: String, context: ModelContext) throws -> StudyListModel {
        guard let list = try context.fetch(FetchDescriptor<StudyListModel>(predicate: #Predicate { $0.id == id })).first else {
            throw StudyListError.missingList
        }
        return list
    }

    private func requireWord(_ id: String, context: ModelContext) throws {
        guard try !context.fetch(FetchDescriptor<KotobaDataModel>(predicate: #Predicate { $0.id == id })).isEmpty else {
            throw StudyListError.missingWord
        }
    }
}
