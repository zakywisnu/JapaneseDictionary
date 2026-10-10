import Foundation
import SwiftData

public struct LessonExample: Codable, Hashable {
    public var japanese: String
    public var english: String
    public var reading: String?
    public init(japanese: String, english: String, reading: String? = nil) {
        self.japanese = japanese; self.english = english; self.reading = reading
    }
}

public struct MaterialSource: Codable, Hashable {
    public var provider: String
    public var sourceID: String
    public var sourceURL: String
    public var license: String
    public var notice: String
    public var snapshot: String
    public var textSHA256: String
    public var parentIDs: [String]
    public init(provider: String, sourceID: String, sourceURL: String, license: String, notice: String, snapshot: String, textSHA256: String, parentIDs: [String] = []) {
        self.provider = provider; self.sourceID = sourceID; self.sourceURL = sourceURL
        self.license = license; self.notice = notice; self.snapshot = snapshot
        self.textSHA256 = textSHA256; self.parentIDs = parentIDs
    }
}

public struct StudyMaterial: Codable, Hashable {
    public var id: String
    public var kind: SavedStudyKind
    public var prompt: String
    public var answer: String
    public var reading: String?
    public var level: String?
    public var notes: String?
    public var category: String?
    public var structures: [String]
    public var examples: [LessonExample]
    public var relatedSourceIDs: [String]
    public var source: MaterialSource?
    public var createdAt: Date
    public var updatedAt: Date
    public init(id: String, kind: SavedStudyKind, prompt: String, answer: String, reading: String? = nil, level: String? = nil, notes: String? = nil, category: String? = nil, structures: [String] = [], examples: [LessonExample] = [], relatedSourceIDs: [String] = [], source: MaterialSource? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id; self.kind = kind; self.prompt = prompt; self.answer = answer
        self.reading = reading; self.level = level; self.notes = notes; self.category = category
        self.structures = structures; self.examples = examples; self.relatedSourceIDs = relatedSourceIDs
        self.source = source; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
public final class StudyMaterialModel {
    @Attribute(.unique) public var key: String
    public var kind: SavedStudyKind
    public var savedID: String
    public var sourceKey: String?
    public var payload: Data
    public init(value: StudyMaterial) throws {
        key = SavedStudyID(kind: value.kind, id: value.id).key
        kind = value.kind; savedID = value.id
        sourceKey = value.source.map { value.kind.rawValue + ":" + $0.provider + ":" + $0.sourceID }
        payload = try JSONEncoder().encode(value)
    }
    public func decodedValue() throws -> StudyMaterial { try JSONDecoder().decode(StudyMaterial.self, from: payload) }
    func apply(_ value: StudyMaterial) throws { payload = try JSONEncoder().encode(value) }
}
