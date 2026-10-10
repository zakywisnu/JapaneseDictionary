import Foundation
import SwiftData

public enum StudyMaterialError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let field): return "The card has invalid \(field). Check this field and save again." }
    }
}

public enum StudyMaterialValidator {
    public static func validate(_ input: StudyMaterial) throws -> StudyMaterial {
        var value = input
        func trimmed(_ text: String?) -> String? {
            guard let text else { return nil }
            let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? nil : result
        }
        value.prompt = trimmed(value.prompt) ?? ""
        value.answer = trimmed(value.answer) ?? ""
        value.reading = trimmed(value.reading); value.notes = trimmed(value.notes)
        value.category = trimmed(value.category); value.level = trimmed(value.level)
        guard [.grammar, .sentence, .customCard].contains(value.kind) else { throw StudyMaterialError.invalid("material type") }
        guard !value.id.isEmpty, !value.prompt.isEmpty, !value.answer.isEmpty else { throw StudyMaterialError.invalid("prompt or answer") }
        guard value.prompt.count <= 500, value.answer.count <= 4_000, (value.reading?.count ?? 0) <= 500, (value.notes?.count ?? 0) <= 4_000 else { throw StudyMaterialError.invalid("text length") }
        guard value.level.map({ ["N1", "N2", "N3", "N4", "N5"].contains($0) }) ?? true else { throw StudyMaterialError.invalid("JLPT level") }
        guard value.category.map({ ["grammar", "sentence", "kana", "other"].contains($0) }) ?? true else { throw StudyMaterialError.invalid("category") }
        guard value.createdAt.timeIntervalSince1970.isFinite, value.updatedAt.timeIntervalSince1970.isFinite, value.updatedAt >= value.createdAt else { throw StudyMaterialError.invalid("dates") }
        if value.kind == .customCard {
            guard value.source == nil else { throw StudyMaterialError.invalid("custom card source") }
        } else {
            guard let source = value.source,
                  [source.provider, source.sourceID, source.sourceURL, source.license, source.notice, source.snapshot].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  source.textSHA256.count == 64, source.textSHA256.allSatisfy({ $0.isHexDigit }),
                  URL(string: source.sourceURL)?.scheme == "https" else { throw StudyMaterialError.invalid("source notice") }
        }
        guard value.examples.allSatisfy({ !$0.japanese.isEmpty && !$0.english.isEmpty }),
              value.structures.allSatisfy({ !$0.isEmpty }), value.relatedSourceIDs.allSatisfy({ !$0.isEmpty }),
              value.source?.parentIDs.allSatisfy({ !$0.isEmpty }) ?? true else { throw StudyMaterialError.invalid("examples or references") }
        return value
    }
}

public protocol StudyMaterialRepository {
    func materials(kind: SavedStudyKind?) throws -> [StudyMaterial]
    func save(_ material: StudyMaterial) throws -> StudyMaterial
    func delete(_ id: SavedStudyID) throws
}

public final class StandardStudyMaterialRepository: StudyMaterialRepository {
    private let store: StudyStore
    private let saveContext: (ModelContext) throws -> Void
    private let now: () -> Date
    public init(store: StudyStore, now: @escaping () -> Date = Date.init, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.store = store; self.now = now; saveContext = save
    }
    public func materials(kind: SavedStudyKind? = nil) throws -> [StudyMaterial] {
        try store.makeContext().fetch(FetchDescriptor<StudyMaterialModel>()).map { try $0.decodedValue() }
            .filter { kind == nil || $0.kind == kind }.sorted { $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt }
    }
    public func save(_ material: StudyMaterial) throws -> StudyMaterial {
        var value = try StudyMaterialValidator.validate(material)
        let context = store.makeContext()
        do {
            let models = try context.fetch(FetchDescriptor<StudyMaterialModel>())
            let key = SavedStudyID(kind: value.kind, id: value.id).key
            if let model = models.first(where: { $0.key == key }) {
                let old = try model.decodedValue()
                guard old.source == value.source else { throw StudyMaterialError.invalid("changed source identity") }
                value.createdAt = old.createdAt
                value = try StudyMaterialValidator.validate(value)
                if old.prompt != value.prompt || old.answer != value.answer || old.reading != value.reading {
                    try clearStudyState(SavedStudyID(kind: value.kind, id: value.id), context: context)
                }
                try model.apply(value)
            } else {
                if let source = value.source {
                    let sourceKey = value.kind.rawValue + ":" + source.provider + ":" + source.sourceID
                    if let saved = models.first(where: { $0.sourceKey == sourceKey }) { return try saved.decodedValue() }
                    value.id = UUID().uuidString
                    value.createdAt = now()
                    value.updatedAt = value.createdAt
                    value = try StudyMaterialValidator.validate(value)
                } else {
                    guard UUID(uuidString: value.id) != nil else { throw StudyMaterialError.invalid("card identity") }
                }
                context.insert(try StudyMaterialModel(value: value))
            }
            try saveContext(context); store.refreshContext()
            return value
        } catch { context.rollback(); throw error }
    }
    public func delete(_ id: SavedStudyID) throws {
        let context = store.makeContext()
        do {
            let key = id.key
            guard let model = try context.fetch(FetchDescriptor<StudyMaterialModel>(predicate: #Predicate { $0.key == key })).first else { throw DataError.dataNotFound }
            context.delete(model)
            try clearStudyState(id, context: context)
            let memberships = try context.fetch(FetchDescriptor<StudyItemMembershipModel>())
            for membership in memberships where membership.value.id == id { context.delete(membership) }
            try saveContext(context); store.refreshContext()
        } catch { context.rollback(); throw error }
    }
}

func clearStudyState(_ id: SavedStudyID, context: ModelContext) throws {
    let key = id.key
    for model in try context.fetch(FetchDescriptor<ReviewRecordModel>(predicate: #Predicate { $0.key == key })) { context.delete(model) }
    for model in try context.fetch(FetchDescriptor<DifficultyRecordModel>(predicate: #Predicate { $0.key == key })) { context.delete(model) }
}
