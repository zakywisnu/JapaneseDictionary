import XCTest
@testable import DataKit

final class KanaCatalogTests: XCTestCase {
    func testCoverageAndUniqueKeys() {
        for script in KanaScript.allCases {
            let entries = KanaCatalog.entries.filter { $0.script == script }
            XCTAssertEqual(entries.filter { $0.group == .basic }.count, 46)
            XCTAssertEqual(entries.filter { $0.group == .voiced }.count, 26)
            XCTAssertEqual(entries.filter { $0.group == .contracted }.count, 33)
        }
        XCTAssertEqual(Set(KanaCatalog.entries.map(\.id)).count, KanaCatalog.entries.count)
        XCTAssertEqual(KanaCatalog.entries.first { $0.kana == "を" }?.reading, "お")
        XCTAssertNil(KanaCatalog.entries.first { $0.kana == "っ" }?.reading)
        XCTAssertNil(KanaCatalog.entries.first { $0.kana == "ー" }?.reading)
    }
    func testEveryGeneratedCardValidatesWithoutSource() throws {
        for entry in KanaCatalog.entries {
            let card = try StudyMaterialValidator.validate(entry.material())
            XCTAssertNotNil(UUID(uuidString: card.id)); XCTAssertNil(card.source)
            XCTAssertEqual(card.category, "kana"); XCTAssertEqual(card.kind, .customCard)
        }
    }
    func testDuplicateMatchingPreservesEditsAndDoesNotStealOtherCards() throws {
        let entry = KanaCatalog.entries[0]
        var edited = entry.material(); edited.notes = "My personal note"; edited.reading = "ああ"
        var unrelated = entry.material(); unrelated.category = "other"
        var changedAnswer = entry.material(); changedAnswer.answer = "personal answer"
        var records = [unrelated, changedAnswer, edited]
        let saver = KanaCardSaver(load: { records }, save: { records.append($0); return $0 })
        XCTAssertEqual(try saver.saveSelection([entry, entry]), [edited])
        XCTAssertEqual(records.count, 3)
        records = [unrelated, changedAnswer]
        let saved = try XCTUnwrap(saver.saveSelection([entry]).first)
        XCTAssertNotEqual(saved.id, unrelated.id); XCTAssertNotEqual(saved.id, changedAnswer.id)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(try saver.saveSelection([entry]).first?.id, saved.id)
    }
    func testPartialFailureCanRetryWithoutDuplicates() throws {
        enum Failure: Error { case injected }
        let entries = Array(KanaCatalog.entries.prefix(2))
        var records: [StudyMaterial] = []; var fail = true
        let saver = KanaCardSaver(load: { records }, save: { value in
            if fail && records.count == 1 { throw Failure.injected }
            records.append(value); return value
        })
        XCTAssertThrowsError(try saver.saveSelection(entries))
        XCTAssertEqual(records.count, 1)
        fail = false
        XCTAssertEqual(try saver.saveSelection(entries).count, 2)
        XCTAssertEqual(records.count, 2)
    }
}
