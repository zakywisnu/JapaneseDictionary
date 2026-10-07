import XCTest
import DataKit
import SwiftData
@testable import DomainKit

final class StudyDeletionTests: XCTestCase {
    func testDeleteFailureDoesNotPublishProgressShadow() throws {
        let previous = UserDefaults.standard.object(forKey: "wordsProgress")
        defer { UserDefaults.standard.set(previous, forKey: "wordsProgress") }
        let sentinel = Data("existing progress".utf8)
        UserDefaults.standard.set(sentinel, forKey: "wordsProgress")
        let useCase = DefaultDeleteKotobaUseCase(mutationRepository: FailingMutations())
        XCTAssertThrowsError(try useCase.execute(kotoba: KotobaParam(id: "saved", kanji: "森", furigana: "もり", english: ["forest"], jlptLevel: .n5, dateAdded: Date(), addedIndex: 8)))
        XCTAssertEqual(UserDefaults.standard.data(forKey: "wordsProgress"), sentinel)
    }
    private struct FailingMutations: StudyMutationRepository {
        func delete(id: SavedStudyID) throws -> StudyProgress { throw Failure.injected }
    }
    private enum Failure: Error { case injected }
}
