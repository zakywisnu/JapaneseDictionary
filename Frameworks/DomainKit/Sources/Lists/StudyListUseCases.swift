import DataKit

public struct StudyListUseCases {
    private let repository: any StudyListRepository
    public init(repository: any StudyListRepository) { self.repository = repository }
    public func lists() throws -> [StudyList] { try repository.lists() }
    public func create(name: String) throws -> StudyList { try repository.create(name: name) }
    public func rename(id: String, name: String) throws { try repository.rename(id: id, name: name) }
    public func delete(id: String) throws { try repository.delete(id: id) }
    public func words(listID: String) throws -> [SavedStudyItem] { try repository.words(listID: listID) }
    public func listIDs(wordID: String) throws -> Set<String> { try repository.listIDs(wordID: wordID) }
    public func setLists(wordID: String, listIDs: Set<String>) throws { try repository.setLists(wordID: wordID, listIDs: listIDs) }
    public func removeWord(listID: String, wordID: String) throws { try repository.removeWord(listID: listID, wordID: wordID) }
    public func items(listID: String) throws -> [SavedStudyItem] { try repository.items(listID: listID) }
    public func listIDs(id: SavedStudyID) throws -> Set<String> { try repository.listIDs(id: id) }
    public func setLists(id: SavedStudyID, listIDs: Set<String>) throws { try repository.setLists(id: id, listIDs: listIDs) }
    public func removeItem(listID: String, id: SavedStudyID) throws { try repository.removeItem(listID: listID, id: id) }
}
