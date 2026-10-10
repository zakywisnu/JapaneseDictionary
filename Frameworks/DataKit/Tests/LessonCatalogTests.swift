import XCTest
@testable import DataKit

final class LessonCatalogTests: XCTestCase {
    func testBundledCorpusIncludesEveryLevelAndParentReferences() throws {
        let materials = try LessonCatalogRepository().materials()
        for material in materials { _ = try StudyMaterialValidator.validate(material) }
        XCTAssertEqual(materials.filter { $0.kind == .grammar }.count, 1031)
        XCTAssertEqual(materials.filter { $0.kind == .sentence }.count, 2056)
        XCTAssertEqual(Set(materials.filter { $0.kind == .grammar }.compactMap(\.level)), Set(["N1", "N2", "N3", "N4", "N5"]))
        XCTAssertTrue(materials.filter { $0.kind == .sentence }.allSatisfy { !($0.source?.parentIDs.isEmpty ?? true) })
    }

    func testMalformedMissingFieldsAndUnsupportedVersionThrow() {
        XCTAssertThrowsError(try LessonCatalogRepository(data: Data("{".utf8)).materials())
        XCTAssertThrowsError(try LessonCatalogRepository(data: Data("{\"version\":1}".utf8)).materials())
        XCTAssertThrowsError(try decode([lesson()], version: 2))
    }

    func testDuplicateInvalidLevelBlankTextAndMissingReferencesThrow() {
        XCTAssertThrowsError(try decode([lesson(), lesson()]))
        var invalid = lesson(); invalid.level = "N6"
        XCTAssertThrowsError(try decode([invalid]))
        invalid = lesson(); invalid.answer = " "
        XCTAssertThrowsError(try decode([invalid]))
        invalid = lesson(); invalid.relatedSourceIDs = ["grammar:missing"]
        XCTAssertThrowsError(try decode([invalid]))
        invalid = lesson(); invalid.source?.license = "unknown"
        XCTAssertThrowsError(try decode([invalid]))
    }

    private func lesson() -> StudyMaterial {
        let date = ISO8601DateFormatter().date(from: "2026-10-08T00:00:00Z")!
        return StudyMaterial(id: "grammar:sample", kind: .grammar, prompt: "見る", answer: "See", level: "N5", examples: [.init(japanese: "見る。", english: "See.")], source: .init(provider: "nihongo mono", sourceID: "grammar:sample", sourceURL: "https://github.com/stndaru/nihongo-mono/blob/\(String(repeating: "a", count: 40))/src/data/grammar/", license: "MIT", notice: "Community material", snapshot: "2026-10-08", textSHA256: String(repeating: "b", count: 64)), createdAt: date, updatedAt: date)
    }

    private func decode(_ materials: [StudyMaterial], version: Int = 1) throws -> [StudyMaterial] {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(materials)
        let value: [String: Any] = ["version": version, "snapshot": "2026-10-08", "commit": String(repeating: "a", count: 40), "materials": try JSONSerialization.jsonObject(with: encoded)]
        return try LessonCatalogRepository(data: JSONSerialization.data(withJSONObject: value)).materials()
    }
}
