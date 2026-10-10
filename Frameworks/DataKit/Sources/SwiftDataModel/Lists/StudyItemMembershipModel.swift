import Foundation
import SwiftData

public struct StudyItemMembership: Codable, Equatable {
    public var listID: String
    public var id: SavedStudyID
    public init(listID: String, id: SavedStudyID) { self.listID = listID; self.id = id }
    public var key: String { "\(listID.utf8.count):\(listID)\(id.key.utf8.count):\(id.key)" }
}

@Model
public final class StudyItemMembershipModel {
    @Attribute(.unique) public var key: String
    public var listID: String
    public var kind: SavedStudyKind
    public var savedID: String
    public init(listID: String, id: SavedStudyID) {
        self.listID = listID; kind = id.kind; savedID = id.id
        key = StudyItemMembership(listID: listID, id: id).key
    }
    public var value: StudyItemMembership { .init(listID: listID, id: .init(kind: kind, id: savedID)) }
}

@discardableResult
func migrateStudyMemberships(context: ModelContext) throws -> Bool {
    let legacy = try context.fetch(FetchDescriptor<StudyListMembershipModel>())
    guard !legacy.isEmpty else { return false }
    var keys = Set(try context.fetch(FetchDescriptor<StudyItemMembershipModel>()).map(\.key))
    for row in legacy {
        let value = StudyItemMembership(listID: row.listID, id: .init(kind: .word, id: row.wordID))
        if keys.insert(value.key).inserted { context.insert(StudyItemMembershipModel(listID: value.listID, id: value.id)) }
        context.delete(row)
    }
    return true
}
