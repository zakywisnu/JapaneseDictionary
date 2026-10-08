import XCTest
import DataKit
import DomainKit
@testable import SwiftUIApps

final class StudyListPresentationTests: XCTestCase {
    func testCreateFailurePreservesNameAndRetryLoads() {
        let repository = ListRepositoryStub()
        let model = StudyListsViewModel(useCases: StudyListUseCases(repository: repository))
        model.send(.setName("Travel"))
        repository.fail = true
        model.send(.create)
        XCTAssertEqual(model.state.name, "Travel")
        XCTAssertNotNil(model.state.actionError)
        model.send(.load)
        XCTAssertNotNil(model.state.error)
        repository.fail = false
        model.send(.load)
        XCTAssertTrue(model.state.lists.isEmpty)
        XCTAssertNil(model.state.error)
    }

    func testMembershipCancelAndFailedSavePreserveOriginal() {
        let repository = ListRepositoryStub()
        repository.selected = ["a"]
        let model = WordListMembershipViewModel(wordID: "word", useCases: StudyListUseCases(repository: repository))
        model.send(.load)
        model.send(.toggle("b"))
        model.send(.cancel)
        XCTAssertEqual(repository.selected, ["a"])
        XCTAssertEqual(model.state.selected, ["a"])
        model.send(.toggle("b"))
        repository.fail = true
        model.send(.save)
        XCTAssertEqual(model.state.original, ["a"])
        XCTAssertEqual(model.state.selected, ["a", "b"])
        XCTAssertFalse(model.state.didSave)
    }

    func testRenameFailurePreservesInputAndLoadedList() {
        let repository = ListRepositoryStub()
        repository.values = [.init(id: "a", name: "Travel", createdAt: Date(), wordCount: 0)]
        let model = StudyListDetailViewModel(id: "a", useCases: StudyListUseCases(repository: repository))
        model.send(.load)
        XCTAssertEqual(model.state.list?.name, "Travel")
        model.send(.setName("New name"))
        repository.fail = true
        model.send(.rename)
        XCTAssertEqual(model.state.name, "New name")
        XCTAssertEqual(model.state.list?.name, "Travel")
        XCTAssertFalse(model.state.didRename)
        XCTAssertNotNil(model.state.actionError)
    }

    func testMembershipRefreshKeepsUnsavedChoicesAndRepeatedSaveIsSafe() {
        let repository = ListRepositoryStub()
        repository.values = ["a", "b"].map { .init(id: $0, name: $0, createdAt: Date(), wordCount: 0) }
        repository.selected = ["a"]
        let model = WordListMembershipViewModel(wordID: "word", useCases: StudyListUseCases(repository: repository))
        model.send(.load)
        model.send(.toggle("b"))
        model.send(.refreshLists)
        XCTAssertEqual(model.state.selected, ["a", "b"])
        model.send(.save)
        model.send(.save)
        XCTAssertEqual(repository.selected, ["a", "b"])
        XCTAssertTrue(model.state.didSave)
    }

    func testListReviewSelectionKeepsOnlySuppliedMemberIDs() {
        let old = ReviewItem(word: Kotoba(id: "member-old", kanji: "木", furigana: "き", english: ["tree"], jlptLevel: .n5, dateAdded: Date(timeIntervalSince1970: 1)))
        let new = ReviewItem(word: Kotoba(id: "member-new", kanji: "森", furigana: "もり", english: ["forest"], jlptLevel: .n5, dateAdded: Date(timeIntervalSince1970: 2)))
        let selected = ReviewSelection(level: "N5", limit: 1).selected([old, new])
        let session = ReviewSession(kind: .words, items: selected, origin: .list(id: "list", name: "Nature"))
        XCTAssertEqual(session.items.map(\.savedID), ["member-new"])
        XCTAssertEqual(session.origin.backTitle, "Back to Nature")
    }

    func testDeletedListProvidesMissingState() {
        let repository = ListRepositoryStub()
        let model = StudyListDetailViewModel(id: "missing", useCases: StudyListUseCases(repository: repository))
        model.send(.load)
        XCTAssertTrue(model.state.isMissing)
        XCTAssertTrue(model.state.words.isEmpty)
    }
}

private final class ListRepositoryStub: StudyListRepository {
    var values: [StudyList] = []
    var fail = false
    var selected: Set<String> = []
    func check() throws { if fail { throw StudyListError.invalidName } }
    func lists() throws -> [StudyList] { try check(); return values }
    func create(name: String) throws -> StudyList { try check(); return .init(id: "a", name: name, createdAt: Date(), wordCount: 0) }
    func rename(id: String, name: String) throws { try check() }
    func delete(id: String) throws { try check() }
    func words(listID: String) throws -> [SavedStudyItem] { try check(); return [] }
    func listIDs(wordID: String) throws -> Set<String> { try check(); return selected }
    func setLists(wordID: String, listIDs: Set<String>) throws { try check(); selected = listIDs }
    func removeWord(listID: String, wordID: String) throws { try check() }
}
